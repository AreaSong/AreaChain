import json
import os
import shutil
from unittest import mock

from app_test_support import AppTestCase, app_manager


class RecoveryInstallTests(AppTestCase):
    def setUp(self):
        super().setUp()
        self.paths.backups.mkdir(mode=0o700, parents=True)
        directory = self.paths.backups / "uninstall-20260101T120000Z-synthetic"
        directory.mkdir(mode=0o700)
        self.original = directory / "AreaChain.app"
        self.paths.app.rename(self.original)
        self.privacy.write_bytes(b"synthetic-private-configuration")

    def reinstall(self, *flags):
        return self.invoke("install", "--no-build", "--no-open", "--previous-app", str(self.original), *flags)

    def assert_preserved(self, installed=False):
        self.assertEqual(self.privacy.read_bytes(), b"synthetic-private-configuration")
        self.assertEqual(self.data.read_bytes(), b"unchanged-user-data")
        self.assertTrue(self.original.is_dir())
        self.assertEqual(self.paths.app.exists(), installed)
        self.assertFalse(any(self.paths.applications.glob(".areachain-install-*")))
        self.assertFalse(any(call[0] == "open" for call in self.command_calls))

    def test_explicit_same_identity_reinstall_preserves_backup_and_data(self):
        result, output, errors = self.reinstall("--yes")
        self.assertEqual(result, 0, errors)
        self.assertIn('"installed": true', output)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertEqual(self.signature(self.original)["codeHash"], "old")
        self.assertEqual(self.saved_apps(), [self.original])
        self.assert_preserved(installed=True)

    def test_dry_run_reports_identity_source_without_creating_lock_or_copying(self):
        result, output, errors = self.reinstall("--dry-run")
        self.assertEqual(result, 0, errors)
        self.assertEqual(json.loads(output)["identitySource"], str(self.original))
        self.assertFalse((self.paths.backups / ".app-manager.lock").exists())
        self.assertFalse(any(call[0] == "ditto" for call in self.tool_calls))
        self.assertFalse(any(call[0].endswith("build.sh") for call in self.command_calls))
        self.assert_preserved()

    def test_backup_is_never_selected_implicitly(self):
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("--previous-app", errors)
        self.assert_preserved()

    def test_every_access_identity_field_must_match(self):
        variants = ({"mode": "local"}, {"teamIdentifier": "OTHER12345"},
                    {"bundleIdentifier": "com.example.other"},
                    {"applicationIdentifier": "OTHER12345.com.example.areachain"},
                    {"keychainGroups": ["other-group"]})
        fixture = self.original / "Contents/fixture.json"
        info_path = self.original / "Contents/Info.plist"
        original_info = info_path.read_bytes()
        original_signature = fixture.read_text()
        for changed in variants:
            with self.subTest(changed=changed):
                signature = {**json.loads(original_signature), **changed}
                fixture.write_text(json.dumps(signature))
                info = app_manager.plistlib.loads(original_info)
                info["CFBundleIdentifier"] = signature["bundleIdentifier"]
                info_path.write_bytes(app_manager.plistlib.dumps(info))
                result, _, errors = self.reinstall("--yes")
                self.assertEqual(result, 1)
                self.assertIn("签名团队、模式、应用标识或钥匙串访问组发生变化", errors)
                self.assert_preserved()
        fixture.write_text(original_signature)
        info_path.write_bytes(original_info)

    def test_original_release_uses_integrity_check_and_allows_debug_reinstall(self):
        fixture = self.original / "Contents/fixture.json"
        fixture.write_text(fixture.read_text().replace('"Debug"', '"Release"'))
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 0, errors)
        self.assertNotIn(self.original, self.verifications)
        checks = [call for call in self.tool_calls if call[:2] == ["codesign", "--verify"]]
        self.assertEqual(sum(call[-1] == str(self.original) for call in checks), 2)
        self.assert_preserved(installed=True)

    def test_corrupt_original_stops_before_copy(self):
        def fail_original(arguments):
            if arguments[:2] == ["codesign", "--verify"] and arguments[-1] == str(self.original):
                raise app_manager.signing.SigningError("模拟原包完整性失败")
            return self.run_tool(arguments)

        with mock.patch.object(app_manager.signing, "run_tool", side_effect=fail_original):
            result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("原包完整性失败", errors)
        self.assertFalse(any(call[0] == "ditto" for call in self.tool_calls))
        self.assert_preserved()

    def test_candidate_still_requires_full_verification(self):
        self.verification_hook = mock.Mock(side_effect=app_manager.signing.SigningError("候选描述文件已过期"))
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("候选描述文件已过期", errors)
        self.assert_preserved()

    def test_existing_app_cannot_be_overridden_by_backup_identity(self):
        self.make_app(self.paths.app, {**self.identity, "teamIdentifier": "OTHER12345"})
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("直接核对现用应用", errors)
        self.assertEqual(self.signature(self.paths.app)["teamIdentifier"], "OTHER12345")
        self.assert_preserved(installed=True)

    def test_current_build_cannot_be_passed_as_original(self):
        result, _, errors = self.invoke("install", "--dry-run", "--previous-app", str(self.source))
        self.assertEqual(result, 1)
        self.assertIn("回退目录", errors)
        self.assert_preserved()

    def test_symlink_original_is_rejected(self):
        real = self.original.with_name("Saved.app")
        self.original.rename(real)
        self.original.symlink_to(real, target_is_directory=True)
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("符号链接", errors)
        self.assert_preserved()

    def test_missing_original_is_rejected(self):
        missing = self.original.parent / "missing" / "AreaChain.app"
        result, _, _ = self.invoke("install", "--dry-run", "--previous-app", str(missing))
        self.assertEqual(result, 1)
        self.assert_preserved()

    def test_unsafe_backup_directories_are_rejected(self):
        for directory in (self.paths.backups, self.original.parent):
            with self.subTest(directory=directory):
                directory.chmod(0o755)
                result, _, errors = self.reinstall("--yes")
                self.assertEqual(result, 1)
                self.assertIn("仅当前用户可访问", errors)
                directory.chmod(0o700)
                self.assert_preserved()

    def test_symlink_backup_root_is_rejected(self):
        moved = self.paths.backups.with_name("MovedBackups")
        self.paths.backups.rename(moved)
        self.paths.backups.symlink_to(moved, target_is_directory=True)
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("符号链接", errors)
        self.assert_preserved()

    def test_unrecognized_backup_directory_is_rejected(self):
        renamed = self.original.parent.with_name("arbitrary-folder")
        self.original.parent.rename(renamed)
        self.original = renamed / "AreaChain.app"
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("回退目录", errors)
        self.assert_preserved()

    def test_operation_lock_also_protects_reinstall(self):
        with app_manager.operation_lock(self.paths):
            result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("另一项安装或卸载", errors)
        self.assert_preserved()

    def test_other_owner_is_rejected(self):
        with mock.patch.object(app_manager.os, "getuid", return_value=os.getuid() + 1):
            result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("当前用户所有", errors)
        self.assert_preserved()

    def test_backup_changed_during_staging_stops_install(self):
        def change_backup():
            fixture = self.original / "Contents/fixture.json"
            fixture.write_text(fixture.read_text().replace('"old"', '"changed"'))

        self.copy_hook = change_backup
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("确认后原应用备份发生变化", errors)
        self.assert_preserved()

    def test_identical_backup_replaced_during_staging_stops_install(self):
        def replace_backup():
            moved = self.original.with_name("Moved.app")
            self.original.rename(moved)
            shutil.copytree(moved, self.original)

        self.copy_hook = replace_backup
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("确认后原应用备份发生变化", errors)
        self.assert_preserved()

    def test_backup_removed_during_staging_stops_install(self):
        moved = self.original.with_name("Moved.app")
        self.copy_hook = lambda: self.original.rename(moved)
        result, _, _ = self.reinstall("--yes")
        self.assertEqual(result, 1)
        moved.rename(self.original)
        self.assert_preserved()

    def test_app_appearing_during_staging_is_not_overwritten(self):
        self.copy_hook = lambda: self.make_app(self.paths.app, {**self.identity, "codeHash": "concurrent"})
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("确认后已安装应用发生变化", errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "concurrent")
        self.assert_preserved(installed=True)

    def test_post_install_failure_restores_absence_and_keeps_original(self):
        def fail_installed(app):
            if app == self.paths.app:
                raise app_manager.signing.SigningError("模拟安装后验签失败")

        self.verification_hook = fail_installed
        result, _, errors = self.reinstall("--yes")
        self.assertEqual(result, 1)
        self.assertIn("已恢复安装前状态", errors)
        self.assertEqual(self.saved_apps(), [self.original])
        self.assert_preserved()

    def test_cancellation_does_not_install_or_consume_original(self):
        with mock.patch.object(app_manager.sys.stdin, "isatty", return_value=True), \
                mock.patch("builtins.input", return_value="CANCEL"):
            result, _, errors = self.reinstall()
        self.assertEqual(result, 1)
        self.assertIn("已取消", errors)
        self.assert_preserved()
