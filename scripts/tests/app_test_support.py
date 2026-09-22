import contextlib
import copy
import io
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import app_manager


class AppTestCase(unittest.TestCase):
    """所有应用、用户目录和外部命令均隔离，不能触达真实安装或钥匙串。"""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="areachain-manager-tests-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.paths = app_manager.Locations(self.root / "project", self.root / "Applications", self.root / "user")
        for path in (self.paths.project, self.paths.applications, self.paths.user):
            path.mkdir()
        self.expected = {"mode": "development", "bundleIdentifier": "com.example.areachain",
                         "teamIdentifier": "ABCDE12345", "distributionReady": False}
        self.identity = {**self.expected, "applicationIdentifier": "ABCDE12345.com.example.areachain",
                         "keychainGroups": ["ABCDE12345.com.example.areachain"], "codeHash": "new",
                         "configuration": "Debug"}
        self.source = self.paths.project / "build/development-DerivedData/Build/Products/Debug/AreaChain.app"
        self.make_app(self.source, self.identity)
        self.make_app(self.paths.app, {**self.identity, "codeHash": "old"})
        self.privacy = self.paths.privacy_configuration(self.expected["bundleIdentifier"])
        self.privacy.parent.mkdir(parents=True)
        self.data = self.privacy.parent / "application-data"
        self.data.write_bytes(b"unchanged-user-data")
        self.process_running = False
        self.build_exit = 0
        self.open_exit = 0
        self.command_calls = []
        self.tool_calls = []
        self.verifications = []
        self.copy_hook = None
        self.verification_hook = None
        self.settings = self.patch(app_manager.signing, "read_settings", return_value=self.expected)
        self.patch(app_manager.signing, "verify_app", side_effect=self.verify)
        self.patch(app_manager.signing, "run_tool", side_effect=self.run_tool)
        self.patch(app_manager.subprocess, "run", side_effect=self.run_command)
        self.patch(app_manager.os, "geteuid", return_value=501)

    def patch(self, target, name, **options):
        patcher = mock.patch.object(target, name, **options)
        result = patcher.start()
        self.addCleanup(patcher.stop)
        return result

    def make_app(self, path, signature):
        contents = path / "Contents"
        contents.mkdir(parents=True)
        info = {"CFBundleIdentifier": signature["bundleIdentifier"], "CFBundleExecutable": "AreaChain"}
        (contents / "Info.plist").write_bytes(plistlib.dumps(info))
        (contents / "fixture.json").write_text(json.dumps(signature))

    def signature(self, app):
        app_manager.bundle_info(app)
        return json.loads((app / "Contents/fixture.json").read_text())

    def verify(self, app, configuration, expected):
        self.verifications.append(app)
        self.assertEqual(configuration, self.signature(app)["configuration"])
        self.assertEqual(self.signature(app)["bundleIdentifier"], expected["bundleIdentifier"])
        if self.verification_hook:
            self.verification_hook(app)
        return {**expected, "staticSignatureVerified": True, "profileExpiresUTC": "2099-01-01T00:00:00+00:00"}

    def run_tool(self, arguments):
        self.tool_calls.append(arguments)
        if arguments[0] == "ditto":
            if self.copy_hook:
                self.copy_hook()
            shutil.copytree(arguments[-2], arguments[-1])
        elif arguments[:2] == ["codesign", "-d"]:
            signature = self.signature(Path(arguments[-1]))
            if "--entitlements" in arguments:
                entitlements = {"com.apple.application-identifier": signature["applicationIdentifier"],
                                "keychain-access-groups": signature["keychainGroups"]}
                if signature.get("configuration") == "Debug":
                    entitlements["get-task-allow"] = True
                return subprocess.CompletedProcess(arguments, 0, plistlib.dumps(entitlements), b"")
            self.assertIn("--verbose=4", arguments)
            authority = ("Signature=adhoc" if signature["mode"] == "local"
                         else "Authority=Apple Development: Synthetic Fixture")
            details = (f"{authority}\nTeamIdentifier={signature['teamIdentifier']}\n"
                       f"CDHash={signature['codeHash']}\n")
            return subprocess.CompletedProcess(arguments, 0, b"", details.encode())
        else:
            self.assertEqual(arguments[:4], ["codesign", "--verify", "--deep", "--strict"])
        return subprocess.CompletedProcess(arguments, 0, b"", b"")

    def run_command(self, arguments, **options):
        self.command_calls.append(arguments)
        if arguments[0] == "pgrep":
            code = 0 if self.process_running else 1
        elif arguments[0] == "open":
            code = self.open_exit
        elif arguments[0] == str(self.paths.project / "scripts/build.sh"):
            self.assertIn(arguments[1:], (["build"], ["release"]))
            code = self.build_exit
        elif arguments[0] in ("osascript", "pkill"):
            self.process_running = False
            code = 0
        else:
            self.fail(f"意外的外部命令：{arguments}")
        return subprocess.CompletedProcess(arguments, code, b"", b"")

    def invoke(self, *arguments):
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            result = app_manager.main(list(arguments), self.paths)
        self.assertEqual(self.data.read_bytes(), b"unchanged-user-data")
        return result, output.getvalue(), errors.getvalue()

    def saved_apps(self):
        return sorted(self.paths.backups.glob("*/AreaChain.app"))

    def assert_original_untouched(self):
        self.assertEqual(self.signature(self.paths.app)["codeHash"], "old")
        self.assertEqual(self.saved_apps(), [])
        self.assertFalse(any(self.paths.applications.glob(".areachain-install-*")))

    def change_candidate(self, **values):
        signature = copy.deepcopy(self.identity)
        signature.update(values)
        (self.source / "Contents/fixture.json").write_text(json.dumps(signature))
