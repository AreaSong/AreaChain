import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


BUILD_SCRIPT = Path(__file__).resolve().parents[1] / "build.sh"
GATE_KEYS = ["AREACHAIN_SYSTEM_KEYCHAIN_QA", "AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID", "AREACHAIN_SYSTEM_KEYCHAIN_PHASE"]


class BuildCommandTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-build-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        (self.root / "bin").mkdir()
        shutil.copy2(BUILD_SCRIPT, self.root / "scripts/build.sh")
        self.trace = self.root / "trace.jsonl"
        common = (
            "import json, os, sys\nfrom pathlib import Path\n"
            "record = {'tool': Path(sys.argv[0]).name, 'args': sys.argv[1:], "
            "'qa': {k:v for k,v in os.environ.items() if 'AREACHAIN_SYSTEM_KEYCHAIN_' in k}}\n"
            "with open(os.environ['AREACHAIN_TEST_TRACE'], 'a') as stream: stream.write(json.dumps(record)+'\\n')\n"
        )
        checker = self.root / "scripts/signing.py"
        checker.write_text(common + "print(json.dumps({'mode': os.environ.get('AREACHAIN_TEST_MODE', 'local')}))\n")
        for name in ("xcodebuild", "pkill", "ditto", "open"):
            stub = self.root / "bin" / name
            stub.write_text("#!/usr/bin/env python3\n" + common + ("sys.exit(99)\n" if name != "xcodebuild" else ""))
            stub.chmod(0o755)
        self.environment = dict(os.environ, PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                                AREACHAIN_TEST_TRACE=str(self.trace))

    def invoke(self, *arguments):
        return subprocess.run(["/bin/bash", str(self.root / "scripts/build.sh"), *arguments],
                              env=self.environment, capture_output=True, text=True, timeout=10)

    def records(self):
        return [json.loads(line) for line in self.trace.read_text().splitlines()] if self.trace.exists() else []

    def xcode_call(self):
        return next(record for record in self.records() if record["tool"] == "xcodebuild")

    def test_default_build_never_installs_or_starts_app(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.xcode_call()["args"][-1], "build")
        self.assertNotIn("-allowProvisioningUpdates", self.xcode_call()["args"])
        self.assertFalse({"pkill", "ditto", "open"} & {row["tool"] for row in self.records()})

    def test_release_selects_release_and_verifies_its_artifact(self):
        result = self.invoke("release")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.xcode_call()["args"]
        self.assertEqual(args[args.index("-configuration") + 1], "Release")
        verifier = self.records()[-1]["args"]
        self.assertIn("verify", verifier)
        self.assertTrue(verifier[-1].endswith("/Release/AreaChain.app"))

    def test_read_only_check_does_not_start_a_build(self):
        self.assertEqual(self.invoke("check-signing").returncode, 0)
        self.assertEqual([row["tool"] for row in self.records()], ["signing.py"])

    def test_provisioning_requires_explicit_development_opt_in(self):
        self.environment["AREACHAIN_TEST_MODE"] = "development"
        self.assertEqual(self.invoke("build", "--allow-provisioning").returncode, 0)
        self.assertIn("-allowProvisioningUpdates", self.xcode_call()["args"])
        self.assertIn("-allowProvisioningDeviceRegistration", self.xcode_call()["args"])

    def test_local_build_cannot_request_provisioning(self):
        self.assertNotEqual(self.invoke("build", "--allow-provisioning").returncode, 0)
        self.assertNotIn("xcodebuild", [row["tool"] for row in self.records()])

    def test_regular_tests_strip_both_forms_of_real_keychain_authorization(self):
        for key in GATE_KEYS + ["TEST_RUNNER_" + key for key in GATE_KEYS]:
            self.environment[key] = "authorized"
        result = self.invoke("test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.xcode_call()["qa"], {})
        self.assertEqual(self.xcode_call()["args"][-1], "test")

    def test_test_filters_are_forwarded_as_individual_arguments(self):
        result = self.invoke("test", "--only-testing", "AreaChainTests/PrivacyVaultTests",
                             "--only-testing", "AreaChainTests/SystemVaultIntegrationTests")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-only-testing:AreaChainTests/PrivacyVaultTests", self.xcode_call()["args"])
        self.assertIn("-only-testing:AreaChainTests/SystemVaultIntegrationTests", self.xcode_call()["args"])

    def test_unsafe_or_ambiguous_commands_stop_before_tools(self):
        for arguments in (("install",), ("test", "--allow-provisioning"),
                          ("release", "--configuration", "Debug"), ("check-signing", "--configuration", "Other"),
                          ("build", "--only-testing", "AreaChainTests"), ("build", "--unknown")):
            with self.subTest(arguments=arguments):
                result = self.invoke(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.records(), [])


if __name__ == "__main__":
    unittest.main()
