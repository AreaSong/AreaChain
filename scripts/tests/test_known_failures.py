"""已知既有失败登记表的归类测试；只用临时目录与模拟命令，不启动 Xcode。"""

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import known_failures

SPEC = importlib.util.spec_from_file_location("quality_gate", SCRIPTS / "quality_gate.py")
quality = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quality)

ENTRY = {"test": "OldTests.flaky", "firstSeen": "d77da2e", "reason": "合成原因", "registered": "2026-10-23"}
FAILING = "** TEST EXECUTE FAILED **\nFailing tests:\n\tOldTests.flaky()\n\tOldTests.flaky()\n"


class KnownFailuresTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-known-failures-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def register(self, *entries, schema=1):
        path = self.root / known_failures.REGISTRY
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"schemaVersion": schema, "entries": list(entries)}), encoding="utf-8")

    def run_tests(self, results, filters=("AreaChainTests/OldTests", "AreaChainTests/NewTests")):
        outputs = iter(results)
        with patch.object(quality, "run_command", side_effect=lambda *a, **k: next(outputs)) as run:
            check = quality.run_swift_tests(list(filters) if filters else None, root=self.root)
        return check, run

    def test_parses_and_normalizes_failing_block(self):
        output = ("x\nFailing tests:\n\tAreaChainTests.SuiteTests.plain()\n\tSuiteTests.param(after:)\n"
                  "\tAreaChainTests/OtherTests/legacy()\n\n** TEST EXECUTE FAILED **\n")
        self.assertEqual(known_failures.failing_tests(output),
                         {"SuiteTests.plain", "SuiteTests.param", "OtherTests.legacy"})
        self.assertEqual(known_failures.failing_tests("no block"), set())

    def test_known_failures_are_listed_but_not_counted(self):
        self.register(ENTRY)
        check, run = self.run_tests([(65, FAILING, "", 1.0)])
        # 测试照常运行：命令里没有任何 skip。
        self.assertNotIn("--skip-testing", run.call_args_list[0].args[0])
        self.assertEqual(check["status"], "passed")
        self.assertIn("已知既有失败 1 项", check["detail"])
        self.assertIn("OldTests.flaky", check["detail"])

    def test_unregistered_failure_still_fails(self):
        self.register(ENTRY)
        output = FAILING + "\tNewTests.broken()\n"
        check, _ = self.run_tests([(65, output.replace("** TEST EXECUTE FAILED **\n", ""), "", 1.0)])
        self.assertEqual(check["status"], "failed")
        self.assertIn("登记表外失败 1 项：NewTests.broken", check["detail"])

    def test_registered_test_that_passed_is_suggested_for_removal(self):
        self.register(ENTRY, {**ENTRY, "test": "UnselectedTests.other"})
        check, _ = self.run_tests([(0, "** TEST SUCCEEDED **", "", 1.0)])
        self.assertEqual(check["status"], "passed")
        self.assertEqual(check["issues"], ["以下登记用例本次运行通过，可从登记表移除：OldTests.flaky"])

    def test_no_removal_hint_when_registered_test_fails_or_was_not_selected(self):
        self.register(ENTRY)
        check, _ = self.run_tests([(65, FAILING, "", 1.0)])
        self.assertEqual(check["issues"], [])
        check, _ = self.run_tests([(0, "", "", 1.0)], filters=("AreaChainTests/NewTests",))
        self.assertEqual(check["issues"], [])

    def test_build_failure_or_timeout_is_never_reclassified(self):
        self.register(ENTRY)
        for code in (1, 124):
            check, _ = self.run_tests([(code, FAILING, "", 1.0)])
            self.assertEqual(check["status"], "failed")
            self.assertEqual(check["issues"], [])

    def test_exit_65_without_failing_block_stays_failed(self):
        self.register(ENTRY)
        check, _ = self.run_tests([(65, "crashed", "", 1.0)])
        self.assertEqual(check["status"], "failed")

    def test_invalid_registry_is_reported_and_not_used(self):
        self.register({"test": "not-an-id", "firstSeen": "x", "reason": "y", "registered": "z"})
        check, _ = self.run_tests([(65, FAILING, "", 1.0)])
        self.assertEqual(check["status"], "failed")
        self.assertTrue(any("类.方法" in issue for issue in check["issues"]))
        self.register(ENTRY, ENTRY)
        self.assertIn("重复登记", known_failures.load(self.root)[1][0])
        self.register(ENTRY, schema=2)
        self.assertTrue(known_failures.load(self.root)[1])

    def test_repository_registry_is_valid(self):
        registry, problems = known_failures.load(SCRIPTS.parent)
        self.assertEqual(problems, [])
        self.assertTrue(registry)


if __name__ == "__main__":
    unittest.main()
