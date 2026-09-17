import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]


class WrapperTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="areachain-wrapper-tests-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.scripts = self.root / "project with spaces" / "scripts"
        self.scripts.mkdir(parents=True)
        self.elsewhere = self.root / "another-directory"
        self.elsewhere.mkdir()
        for name in ("app.sh", "install.sh", "uninstall.sh"):
            shutil.copy2(SCRIPTS / name, self.scripts / name)
        (self.scripts / "app_manager.py").write_text(
            "import json, os, sys\nprint(json.dumps(sys.argv[1:]))\n"
            "sys.exit(int(os.environ.get('AREACHAIN_WRAPPER_EXIT', '0')))\n")

    def invoke(self, script, *arguments, environment=None):
        return subprocess.run([str(self.scripts / script), *arguments], cwd=self.elsewhere,
                              capture_output=True, text=True, env=environment, timeout=10)

    def test_install_wrapper_forwards_command_and_flags_from_another_directory(self):
        result = self.invoke("install.sh", "--no-build", "--no-open", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ["install", "--no-build", "--no-open", "--dry-run"])

    def test_uninstall_wrapper_forwards_recoverable_uninstall(self):
        result = self.invoke("uninstall.sh", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ["uninstall", "--dry-run"])

    def test_app_wrapper_preserves_individual_arguments_and_exit_code(self):
        environment = dict(os.environ, AREACHAIN_WRAPPER_EXIT="7")
        result = self.invoke("app.sh", "delete", "argument with spaces", environment=environment)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(json.loads(result.stdout), ["delete", "argument with spaces"])

    def test_real_help_entry_points_work_without_project_cwd_or_live_actions(self):
        for script in ("app.sh", "install.sh", "uninstall.sh"):
            with self.subTest(script=script):
                result = subprocess.run([str(SCRIPTS / script), "--help"], cwd=self.elsewhere,
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("usage:", result.stdout)
