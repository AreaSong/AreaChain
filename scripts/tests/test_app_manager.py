import json
import os
import plistlib
import shutil
from unittest import mock

from app_test_support import AppTestCase, app_manager


class InstallTests(AppTestCase):
    def test_default_install_builds_debug_preserves_old_app_and_requests_launch(self):
        result, output, errors = self.invoke("install", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertEqual(self.signature(self.saved_apps()[0])["codeHash"], "old")
        self.assertIn([str(self.paths.project / "scripts/build.sh"), "build"], self.command_calls)
        self.assertIn(["open", str(self.paths.app)], self.command_calls)
        self.assertIn('"configuration": "Debug"', output)
        self.assertIn('"runtimeVerified": false', output)
        self.assertIn('"dataBackupCreated": false', output)
        self.assertFalse(any(self.paths.applications.glob(".areachain-install-*")))

    def test_release_option_builds_and_installs_the_release_product(self):
        release = self.source.parent.parent / "Release" / "AreaChain.app"
        self.make_app(release, {**self.identity, "configuration": "Release"})
        result, output, errors = self.invoke("install", "--release", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertEqual(self.signature(self.paths.app)["configuration"], "Release")
        self.assertIn([str(self.paths.project / "scripts/build.sh"), "release"], self.command_calls)
        self.assertIn('"configuration": "Release"', output)

    def test_debug_install_replaces_release_app_with_the_same_signature_identity(self):
        shutil.rmtree(self.paths.app)
        self.make_app(self.paths.app, {**self.identity, "codeHash": "old", "configuration": "Release"})
        result, _, errors = self.invoke("install", "--no-build", "--no-open", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertEqual(self.signature(self.paths.app)["configuration"], "Debug")

    def test_no_build_and_no_open_only_install_existing_candidate(self):
        result, _, errors = self.invoke("install", "--no-build", "--no-open", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertEqual({call[0] for call in self.command_calls}, {"pgrep"})
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")

    def test_dry_run_never_builds_copies_launches_or_creates_recovery_paths(self):
        result, output, errors = self.invoke("install", "--dry-run")
        self.assertEqual(result, 0, errors)
        self.assertTrue(json.loads(output)["dryRun"])
        self.assert_original_untouched()
        self.assertFalse(self.paths.backups.exists())
        self.assertEqual({call[0] for call in self.command_calls}, {"pgrep"})
        self.assertNotIn("ditto", [call[0] for call in self.tool_calls])

    def test_build_failure_does_not_install(self):
        self.build_exit = 1
        self.process_running = True
        result, _, errors = self.invoke("install", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("构建失败", errors)
        self.assert_original_untouched()
        self.assertTrue(self.process_running)
        self.assertFalse(any(call[0] in ("osascript", "pkill") for call in self.command_calls))

    def test_running_app_is_automatically_quit_during_install(self):
        self.process_running = True
        result, _, errors = self.invoke("install", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertFalse(self.process_running)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertIn(["osascript", "-e", 'tell application "AreaChain" to quit'], self.command_calls)

    def test_signature_identity_changes_cannot_be_bypassed_by_yes(self):
        for change in ({"teamIdentifier": "OTHER12345"}, {"mode": "local"},
                       {"applicationIdentifier": "DIFFERENT.com.example.areachain"},
                       {"keychainGroups": ["ABCDE12345.other"]}):
            with self.subTest(change=change):
                self.change_candidate(**change)
                result, _, errors = self.invoke("install", "--no-build", "--yes")
                self.assertEqual(result, 1)
                self.assertIn("签名团队、模式", errors)
                self.assert_original_untouched()

    def test_missing_candidate_fails_before_any_copy(self):
        shutil.rmtree(self.source)
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("应用不存在", errors)
        self.assert_original_untouched()

    def test_failed_candidate_verification_preserves_installed_app(self):
        self.verification_hook = mock.Mock(side_effect=app_manager.signing.SigningError("描述文件已过期"))
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("描述文件已过期", errors)
        self.assert_original_untouched()

    def test_first_install_without_private_configuration_is_allowed(self):
        shutil.rmtree(self.paths.app)
        result, _, errors = self.invoke("install", "--no-build", "--no-open", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertEqual(self.saved_apps(), [])

    def test_missing_installed_app_with_private_configuration_fails_closed(self):
        shutil.rmtree(self.paths.app)
        self.privacy.write_bytes(b"private-vault-configuration")
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("遗留私密锁", errors)
        self.assertFalse(self.paths.app.exists())
        self.assertEqual(self.privacy.read_bytes(), b"private-vault-configuration")

    def test_candidate_changed_during_copy_is_rejected(self):
        self.copy_hook = lambda: self.change_candidate(codeHash="unconfirmed-build")
        result, _, _ = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assert_original_untouched()

    def test_privacy_configuration_created_while_confirming_stops_first_install(self):
        shutil.rmtree(self.paths.app)
        self.copy_hook = lambda: self.privacy.write_bytes(b"new-private-configuration")
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("遗留私密锁", errors)
        self.assertFalse(self.paths.app.exists())

    def test_staging_creation_failure_does_not_leave_empty_recovery_directory(self):
        original = app_manager.tempfile.mkdtemp

        def create(**options):
            if options["prefix"] == ".areachain-install-":
                raise OSError("模拟暂存目录创建失败")
            return original(**options)

        with mock.patch.object(app_manager.tempfile, "mkdtemp", side_effect=create):
            result, _, _ = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assert_original_untouched()
        self.assertFalse(any(path.is_dir() for path in self.paths.backups.iterdir()))

    def test_post_install_verification_failure_restores_previous_app(self):
        def fail_installed(app):
            if app == self.paths.app and self.signature(app)["codeHash"] == "new":
                raise app_manager.signing.SigningError("模拟安装后验签失败")

        self.verification_hook = fail_installed
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("已恢复安装前状态", errors)
        self.assert_original_untouched()

    def test_failed_rollback_preserves_original_app_in_recovery_directory(self):
        original_rename = os.rename

        def rename(source, destination):
            if self.paths.backups in source.parents and destination == self.paths.app:
                raise OSError("模拟回退失败")
            original_rename(source, destination)

        def fail_installed(app):
            if app == self.paths.app:
                raise app_manager.signing.SigningError("模拟安装后失败")

        self.verification_hook = fail_installed
        with mock.patch.object(app_manager.os, "rename", side_effect=rename):
            result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("自动回退未完成", errors)
        self.assertEqual(self.signature(self.saved_apps()[0])["codeHash"], "old")

    def test_launch_failure_does_not_roll_back_an_app_that_may_have_started(self):
        self.open_exit = 1
        result, output, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn('"installed": true', output)
        self.assertIn("启动请求失败", errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "new")
        self.assertEqual(self.signature(self.saved_apps()[0])["codeHash"], "old")


class ManagementTests(AppTestCase):
    def test_uninstall_moves_only_the_app_and_preserves_private_configuration(self):
        self.privacy.write_bytes(b"private-vault-configuration")
        result, _, errors = self.invoke("uninstall", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertFalse(self.paths.app.exists())
        self.assertEqual(self.signature(self.saved_apps()[0])["codeHash"], "old")
        self.assertEqual(self.privacy.read_bytes(), b"private-vault-configuration")
        self.assertEqual(self.tool_calls, [])

    def test_delete_is_a_recoverable_uninstall_alias(self):
        result, output, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertIn('"keychainPreserved": true', output)
        self.assertFalse(self.paths.app.exists())
        self.assertEqual(len(self.saved_apps()), 1)

    def test_uninstall_dry_run_does_not_create_recovery_paths(self):
        result, output, errors = self.invoke("delete", "--dry-run")
        self.assertEqual(result, 0, errors)
        self.assertTrue(json.loads(output)["dryRun"])
        self.assert_original_untouched()
        self.assertFalse(self.paths.backups.exists())

    def test_uninstall_is_idempotent_when_no_app_is_installed(self):
        shutil.rmtree(self.paths.app)
        result, output, errors = self.invoke("uninstall", "--yes")
        self.assertEqual(result, 0, errors)
        self.assertFalse(json.loads(output)["installed"])
        self.assertFalse(self.paths.backups.exists())

    def test_running_app_cannot_be_uninstalled(self):
        self.process_running = True
        result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("正常退出", errors)
        self.assert_original_untouched()

    def test_status_is_read_only_and_reports_signature_and_running_state(self):
        self.process_running = True
        result, output, errors = self.invoke("status")
        self.assertEqual(result, 0, errors)
        status = json.loads(output)
        self.assertTrue(status["running"])
        self.assertTrue(status["signature"]["staticSignatureVerified"])
        self.assert_original_untouched()
        self.assertFalse(self.paths.backups.exists())

    def test_status_signature_failure_returns_nonzero_and_structured_error(self):
        self.verification_hook = mock.Mock(side_effect=app_manager.signing.SigningError("模拟验签失败"))
        result, output, _ = self.invoke("status")
        self.assertEqual(result, 1)
        self.assertIn("模拟验签失败", json.loads(output)["verificationError"])

    def test_status_inspection_failure_still_reports_installation_state(self):
        with mock.patch.object(app_manager, "inspect_signature", side_effect=ValueError("模拟无法读取签名")):
            result, output, _ = self.invoke("status")
        self.assertEqual(result, 1)
        self.assertTrue(json.loads(output)["installed"])
        self.assertIn("模拟无法读取签名", json.loads(output)["verificationError"])

    def test_start_validates_then_only_requests_launch(self):
        result, output, errors = self.invoke("start")
        self.assertEqual(result, 0, errors)
        self.assertEqual(self.command_calls, [["open", str(self.paths.app)]])
        self.assertFalse(json.loads(output)["runtimeVerified"])
        self.assertEqual(self.verifications, [self.paths.app])

    def test_start_refuses_invalid_signature(self):
        self.verification_hook = mock.Mock(side_effect=app_manager.signing.SigningError("模拟验签失败"))
        result, _, _ = self.invoke("start")
        self.assertEqual(result, 1)
        self.assertEqual(self.command_calls, [])

    def test_noninteractive_write_requires_explicit_yes(self):
        with mock.patch.object(app_manager.sys.stdin, "isatty", return_value=False):
            result, _, errors = self.invoke("delete")
        self.assertEqual(result, 1)
        self.assertIn("非交互环境", errors)
        self.assert_original_untouched()

    def test_cancelled_confirmation_never_changes_installed_app(self):
        with mock.patch.object(app_manager.sys.stdin, "isatty", return_value=True), \
                mock.patch("builtins.input", return_value="cancel"):
            result, _, errors = self.invoke("uninstall")
        self.assertEqual(result, 1)
        self.assertIn("已取消", errors)
        self.assert_original_untouched()

    def test_root_write_is_rejected_even_with_yes(self):
        with mock.patch.object(app_manager.os, "geteuid", return_value=0):
            result, _, errors = self.invoke("install", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("不要使用 sudo", errors)
        self.assert_original_untouched()

    def test_corrupt_plist_has_a_controlled_error_instead_of_a_traceback(self):
        (self.paths.app / "Contents/Info.plist").write_bytes(plistlib.dumps(["invalid"]))
        result, _, errors = self.invoke("uninstall", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("Info.plist", errors)
        self.assertTrue(self.paths.app.exists())

    def test_symlink_installation_is_never_followed_or_removed(self):
        original = self.paths.applications / "original.app"
        self.paths.app.rename(original)
        self.paths.app.symlink_to(original, target_is_directory=True)
        result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("符号链接", errors)
        self.assertTrue(original.is_dir())
        self.assertTrue(self.paths.app.is_symlink())

    def test_shared_recovery_directory_permissions_are_not_silently_changed(self):
        self.paths.backups.mkdir(parents=True, mode=0o755)
        self.paths.backups.chmod(0o755)
        result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("仅当前用户可访问", errors)
        self.assertEqual(self.paths.backups.stat().st_mode & 0o777, 0o755)
        self.assert_original_untouched()

    def test_parallel_install_or_uninstall_fails_without_touching_existing_app(self):
        with app_manager.operation_lock(self.paths):
            for arguments in (("install", "--no-build", "--yes"), ("delete", "--yes")):
                with self.subTest(arguments=arguments):
                    result, _, errors = self.invoke(*arguments)
                    self.assertEqual(result, 1)
                    self.assertIn("另一项安装或卸载", errors)
                    self.assert_original_untouched()
        result, _, errors = self.invoke("install", "--no-build", "--no-open", "--yes")
        self.assertEqual(result, 0, errors)

    def test_symlink_lock_file_cannot_redirect_writes(self):
        self.paths.backups.mkdir(parents=True, mode=0o700)
        (self.paths.backups / ".app-manager.lock").symlink_to(self.data)
        result, _, _ = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assert_original_untouched()

    def test_uninstall_rejects_app_replaced_with_identical_info_during_confirmation(self):
        def replace(*arguments):
            self.paths.app.rename(self.paths.applications / "saved.app")
            self.make_app(self.paths.app, {**self.identity, "codeHash": "replacement"})

        with mock.patch.object(app_manager, "confirm", side_effect=replace):
            result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("确认后应用被替换", errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "replacement")
        self.assertEqual(self.saved_apps(), [])
