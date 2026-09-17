import contextlib
import io
import os
import plistlib
import shutil
import subprocess
from unittest import mock

from app_test_support import AppTestCase, app_manager


class ValidationTests(AppTestCase):
    def test_signature_inspection_reads_identity_and_normalizes_keychain_groups(self):
        self.change_candidate(keychainGroups=["group-b", "group-a"])
        signature = app_manager.inspect_signature(self.source)
        self.assertEqual(signature["teamIdentifier"], "ABCDE12345")
        self.assertEqual(signature["keychainGroups"], ["group-a", "group-b"])
        self.assertEqual(signature["codeHash"], "new")

    def test_local_signature_does_not_treat_team_not_set_as_a_team(self):
        self.change_candidate(mode="local", teamIdentifier="not set", applicationIdentifier="", keychainGroups=[])
        signature = app_manager.inspect_signature(self.source)
        self.assertEqual(signature["mode"], "local")
        self.assertEqual(signature["teamIdentifier"], "")

    def test_developer_id_signature_is_out_of_scope_for_this_tool(self):
        replies = [subprocess.CompletedProcess([], 0, b"", b"Authority=Developer ID Application: Fixture\n"),
                   subprocess.CompletedProcess([], 0, plistlib.dumps({}), b"")]
        with mock.patch.object(app_manager.signing, "run_tool", side_effect=replies):
            with self.assertRaisesRegex(app_manager.AppError, "仅管理本机临时签名或 Apple Development"):
                app_manager.inspect_signature(self.source)

    def test_non_dictionary_entitlements_are_rejected(self):
        replies = [subprocess.CompletedProcess([], 0, b"", b"Signature=adhoc\n"),
                   subprocess.CompletedProcess([], 0, plistlib.dumps(["invalid"]), b"")]
        with mock.patch.object(app_manager.signing, "run_tool", side_effect=replies):
            with self.assertRaisesRegex(app_manager.AppError, "签名权限必须是字典"):
                app_manager.inspect_signature(self.source)

    def test_non_string_keychain_groups_are_rejected(self):
        self.change_candidate(keychainGroups=[123])
        with self.assertRaisesRegex(app_manager.AppError, "钥匙串访问组格式无效"):
            app_manager.inspect_signature(self.source)

    def test_qa_candidate_cannot_replace_daily_app(self):
        for bundle in ("com.example.qa.areachain", "com.example.areachain-tests", "com.example.baseline"):
            with self.subTest(bundle=bundle):
                path = self.source / "Contents/Info.plist"
                info = plistlib.loads(path.read_bytes())
                info["CFBundleIdentifier"] = bundle
                path.write_bytes(plistlib.dumps(info))
                result, _, errors = self.invoke("install", "--no-build", "--yes")
                self.assertEqual(result, 1)
                self.assertIn("QA／测试应用", errors)
                self.assert_original_untouched()

    def test_symlink_contents_directory_is_rejected(self):
        contents = self.paths.app / "Contents"
        external = self.paths.applications / "external-contents"
        contents.rename(external)
        contents.symlink_to(external, target_is_directory=True)
        result, _, errors = self.invoke("uninstall", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("符号链接", errors)
        self.assertTrue(external.exists())

    def test_symlink_recovery_root_is_rejected(self):
        self.paths.backups.parent.mkdir(parents=True)
        self.paths.backups.symlink_to(self.paths.user, target_is_directory=True)
        result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("符号链接", errors)
        self.assertTrue(self.paths.app.exists())

    def test_dangling_privacy_configuration_also_stops_first_install(self):
        shutil.rmtree(self.paths.app)
        self.privacy.symlink_to(self.paths.user / "missing-configuration")
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("遗留私密锁", errors)
        self.assertTrue(self.privacy.is_symlink())

    def test_process_lookup_failure_is_not_treated_as_stopped(self):
        with mock.patch.object(app_manager.subprocess, "run", return_value=subprocess.CompletedProcess([], 2)):
            result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("无法确认", errors)
        self.assert_original_untouched()

    def test_invalid_argument_combinations_stop_before_any_tool(self):
        for arguments in (("delete", "--dry-run", "--yes"), ("install", "--allow-provisioning"),
                          ("install", "--dry-run", "--yes"), ("delete", "--purge"), ("unknown",)):
            with self.subTest(arguments=arguments), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    app_manager.main(list(arguments), self.paths)
                self.assertEqual(error.exception.code, 2)
                self.assertEqual(self.tool_calls, [])
                self.assertEqual(self.command_calls, [])


class FailureTests(AppTestCase):
    def test_copy_failure_preserves_original_and_cleans_partial_stage(self):
        def fail_copy():
            raise OSError("模拟复制失败")

        self.copy_hook = fail_copy
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("模拟复制失败", errors)
        self.assert_original_untouched()

    def test_staging_verification_failure_never_moves_original(self):
        def fail_staged(app):
            if app not in (self.source, self.paths.app):
                raise app_manager.signing.SigningError("模拟暂存包验签失败")

        self.verification_hook = fail_staged
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("暂存包验签失败", errors)
        self.assert_original_untouched()

    def test_app_started_during_staging_stops_install(self):
        self.copy_hook = lambda: setattr(self, "process_running", True)
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("正常退出", errors)
        self.assert_original_untouched()

    def test_old_app_changed_during_staging_is_not_overwritten(self):
        def modify_installed():
            fixture = self.paths.app / "Contents/fixture.json"
            fixture.write_text(fixture.read_text().replace('"old"', '"changed"'))

        self.copy_hook = modify_installed
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("确认后已安装应用发生变化", errors)
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "changed")
        self.assertEqual(self.saved_apps(), [])

    def test_candidate_rename_failure_restores_original(self):
        original_rename = os.rename

        def rename(source, destination):
            if source.parent.name.startswith(".areachain-install-"):
                raise OSError("模拟候选包切换失败")
            original_rename(source, destination)

        with mock.patch.object(app_manager.os, "rename", side_effect=rename):
            result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("已恢复安装前状态", errors)
        self.assert_original_untouched()

    def test_first_install_failure_restores_absent_state(self):
        shutil.rmtree(self.paths.app)

        def fail_installed(app):
            if app == self.paths.app:
                raise app_manager.signing.SigningError("模拟安装后验签失败")

        self.verification_hook = fail_installed
        result, _, errors = self.invoke("install", "--no-build", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("已恢复安装前状态", errors)
        self.assertFalse(self.paths.app.exists())
        self.assertEqual(self.saved_apps(), [])

    def test_uninstall_move_failure_keeps_application_and_cleans_empty_recovery(self):
        with mock.patch.object(app_manager.os, "rename", side_effect=OSError("模拟卸载失败")):
            result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("模拟卸载失败", errors)
        self.assert_original_untouched()
        self.assertFalse(any(path.is_dir() for path in self.paths.backups.iterdir()))

    def test_operation_lock_is_released_after_failure(self):
        with self.assertRaisesRegex(RuntimeError, "模拟中断"):
            with app_manager.operation_lock(self.paths):
                raise RuntimeError("模拟中断")
        with app_manager.operation_lock(self.paths):
            self.assertTrue((self.paths.backups / ".app-manager.lock").is_file())

    def test_cross_filesystem_recovery_is_rejected_without_moving_app(self):
        self.paths.backups.mkdir(mode=0o700, parents=True)
        original_stat = app_manager.Path.stat

        def attributes(path, **options):
            result = original_stat(path, **options)
            if path == self.paths.backups:
                values = list(result)
                values[2] += 1
                return os.stat_result(values)
            return result

        with mock.patch.object(app_manager.Path, "stat", attributes):
            result, _, errors = self.invoke("delete", "--yes")
        self.assertEqual(result, 1)
        self.assertIn("不在同一文件系统", errors)
        self.assert_original_untouched()
