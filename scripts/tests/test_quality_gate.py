"""质量门禁的纯函数和临时夹具测试；不启动 Xcode、不读取用户数据。"""

import importlib.util
import json
import math
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "quality_gate.py"
SPEC = importlib.util.spec_from_file_location("quality_gate", SCRIPT)
quality = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quality)


class QualityGateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-quality-gate-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_infer_profile_prefers_swift_changes(self):
        self.assertEqual(quality.infer_profile(["README.md", "AreaChain/Domain/DayKey.swift"]), "swift")
        self.assertEqual(quality.infer_profile(["scripts/check.py"]), "static")
        self.assertEqual(quality.infer_profile(["docs/quality-gates.md"]), "docs")

    def test_infer_profile_reads_performance_scopes_from_current_root(self):
        self.write("AreaChain/App/App.swift", "struct App {}\n")
        self.write("docs/performance-baselines.json", json.dumps({
            "schemaVersion": 1,
            "entries": [{"scope": "AreaChain/App/App.swift"}],
        }))
        self.assertEqual(quality.infer_profile(["AreaChain/App/App.swift"], self.root), "performance")

    def test_static_profile_does_not_require_swift_toolchain(self):
        self.assertFalse(quality.needs_swift_toolchain("static"))
        self.assertTrue(quality.needs_swift_toolchain("swift"))
        self.assertTrue(quality.needs_swift_toolchain("release"))

    def test_strict_swiftlint_without_change_scope_is_blocked(self):
        with patch.object(quality.shutil, "which", return_value="/usr/bin/swiftlint"):
            result = quality.run_swiftlint(self.root, [], strict=True)
        self.assertEqual(result["status"], "blocked")
        self.assertIn("--base-ref", result["detail"])

    def test_strict_swiftlint_allows_deletion_only_scope(self):
        with patch.object(quality.shutil, "which", return_value="/usr/bin/swiftlint"):
            result = quality.run_swiftlint(self.root, ["AreaChain/Deleted.swift"], strict=True)
        self.assertEqual(result["status"], "skipped")

    def test_changed_files_includes_deletions_and_base_ref(self):
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.email", "test@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.name", "Test"], check=True)
        first = self.write("AreaChain/First.swift", "struct First {}\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "--quiet", "-m", "first"], check=True)
        base = subprocess.run(["git", "-C", str(self.root), "rev-parse", "HEAD"],
                              check=True, capture_output=True, text=True).stdout.strip()
        second = self.write("AreaChain/Second.swift", "struct Second {}\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "--quiet", "-m", "second"], check=True)
        first.unlink()
        self.assertEqual(
            set(quality.changed_files(self.root, base)),
            {"AreaChain/First.swift", "AreaChain/Second.swift"},
        )

    def test_changed_files_preserves_unicode_paths(self):
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.email", "test@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.name", "Test"], check=True)
        self.write("README.md", "base\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "--quiet", "-m", "base"], check=True)
        self.write("AreaChain/中文.swift", "struct Example {}\n")
        paths = quality.changed_files(self.root)
        self.assertEqual(paths, ["AreaChain/中文.swift"])
        self.assertEqual(quality.infer_profile(paths, self.root), "swift")

    def test_changed_files_fails_closed_when_git_scope_is_unavailable(self):
        with patch.object(quality, "run_command", return_value=(128, "", "bad ref", 0.1)):
            with self.assertRaises(RuntimeError):
                quality.changed_files(self.root, "missing")

    def test_diff_check_covers_base_worktree_and_untracked_files(self):
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.email", "test@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.root), "config", "user.name", "Test"], check=True)
        self.write("README.md", "first\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "--quiet", "-m", "first"], check=True)
        base = subprocess.run(["git", "-C", str(self.root), "rev-parse", "HEAD"],
                              check=True, capture_output=True, text=True).stdout.strip()
        self.write("README.md", "second\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "--quiet", "-m", "second"], check=True)
        self.write("README.md", "worktree trailing  \n")
        self.write("new.txt", "untracked trailing \n")
        result = quality.run_diff_check(self.root, ["README.md", "new.txt"], base)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any(item["file"].endswith("new.txt") for item in result["issues"]))

    def test_advisory_swiftlint_excludes_generated_build_directory(self):
        self.write("AreaChain/Example.swift", "struct Example {}\n")
        with patch.object(quality.shutil, "which", return_value="/usr/bin/swiftlint"), \
                patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            result = quality.run_swiftlint(self.root, ["AreaChain/Example.swift"])
        self.assertEqual(result["status"], "passed")
        self.assertEqual(run.call_args.args[0][-2:], ["AreaChain", "AreaChainTests"])

    def test_security_scanner_flags_private_key_and_sensitive_log(self):
        private_key = "-----BEGIN " + "PRIVATE KEY-----"
        sensitive_log = "NSLog(\"title=%@\", " + "request." + "title)"
        path = self.write("AreaChain/Services/Example.swift",
                          "\nprivate let key = \"" + private_key + "\"\n"
                          + sensitive_log + "\n")
        findings = quality.security_findings([path])
        self.assertEqual({item["severity"] for item in findings}, {"high", "medium"})

    def test_security_scanner_does_not_flag_normal_logs(self):
        path = self.write("AreaChain/Services/Example.swift", "NSLog(\"count=%ld\", count)\n")
        self.assertEqual(quality.security_findings([path]), [])

    def test_security_scanner_flags_common_token_prefixes(self):
        github_token = "ghp_" + "A" * 24
        fine_grained_token = "github_pat_" + "B" * 24
        openai_token = "sk-" + "C" * 24
        path = self.write("scripts/example.py", "\n".join((github_token, fine_grained_token, openai_token)))
        findings = quality.security_findings([path])
        self.assertEqual(len(findings), 3)
        self.assertTrue(all(item["severity"] == "high" for item in findings))

    def test_comment_contract_flags_untracked_todo_and_suppression(self):
        path = self.write("AreaChain/Example.swift", "// TODO: later\n// swiftlint:disable line_length\n")
        result = quality.run_comment_check(self.root, ["AreaChain/Example.swift"])
        self.assertEqual(result["status"], "warning")
        self.assertEqual(len(result["issues"]), 2)

    def test_performance_manifest_accepts_provisional_and_unestablished_entries(self):
        self.write("AreaChain/Domain/Rule.swift", "struct Rule {}\n")
        self.write("AreaChainTests/Domain/RuleTests.swift", "// fixture\n")
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{
                "id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                "test": "AreaChainTests/Domain/RuleTests.swift",
                "testFilter": "AreaChainTests/RuleTests", "metric": "wall_ms",
                "budget": 10, "status": "provisional", "source": "fixture:1", "note": "fixture"
            }]
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "passed")

    def test_performance_manifest_reports_missing_source(self):
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{
                "id": "missing", "scope": "AreaChain/Domain/Missing.swift",
                "test": None, "testFilter": None, "metric": "wall_ms", "budget": None,
                "status": "not-established", "source": None, "note": "fixture"
            }]
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertIn("scope 不存在", result["issues"][0]["detail"])

    def test_performance_manifest_rejects_non_object_entry(self):
        self.write("docs/performance-baselines.json", json.dumps({
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": ["bad"],
        }))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertIn("必须是对象", result["issues"][0]["detail"])

    def test_performance_manifest_rejects_non_object_root(self):
        self.write("docs/performance-baselines.json", "[]\n")
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertIn("顶层必须是对象", result["issues"][0]["detail"])

    def test_performance_manifest_rejects_non_list_entries(self):
        self.write("docs/performance-baselines.json", json.dumps({"schemaVersion": 1, "entries": 1}))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertIn("结构或版本", result["issues"][0]["detail"])

    def test_performance_manifest_rejects_nonfinite_budget_and_missing_test(self):
        self.write("AreaChain/Domain/Rule.swift", "struct Rule {}\n")
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{
                "id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                "test": None, "testFilter": None, "metric": "", "budget": math.nan,
                "status": "observed", "source": None, "note": ""
            }]
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        details = " ".join(item["detail"] for item in result["issues"])
        self.assertIn("非有限数字", details)

    def test_performance_warning_only_tracks_relevant_pending_scope(self):
        self.write("AreaChain/Domain/Rule.swift", "struct Rule {}\n")
        self.write("AreaChain/App/App.swift", "struct App {}\n")
        self.write("AreaChainTests/Domain/RuleTests.swift", "// fixture\n")
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [
                {"id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                 "test": "AreaChainTests/Domain/RuleTests.swift", "testFilter": "AreaChainTests/RuleTests",
                 "metric": "wall_ms", "budget": 10, "status": "provisional",
                 "source": "fixture:1", "note": "fixture"},
                {"id": "startup", "scope": "AreaChain/App/App.swift", "test": None,
                 "testFilter": None, "metric": "wall_ms", "budget": None,
                 "status": "not-established", "source": None, "note": "fixture"},
            ],
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        unrelated = quality.run_performance_contract(
            self.root, ["AreaChain/Domain/Rule.swift"], require_measurement=True)
        related = quality.run_performance_contract(
            self.root, ["AreaChain/App/App.swift"], require_measurement=True)
        self.assertEqual(unrelated["status"], "passed")
        self.assertEqual(related["status"], "warning")

    def test_performance_tests_are_loaded_from_manifest(self):
        self.write("docs/performance-baselines.json", json.dumps({
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{"id": "rule", "status": "provisional",
                         "testFilter": "AreaChainTests/RuleTests"}],
        }))
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            result = quality.run_performance_tests(self.root)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(run.call_args.args[0][-2:], ["--only-testing", "AreaChainTests/RuleTests"])

    def test_observed_performance_entry_requires_measurement_fields(self):
        self.write("AreaChain/Domain/Rule.swift", "struct Rule {}\n")
        self.write("AreaChainTests/Domain/RuleTests.swift", "// fixture\n")
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{
                "id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                "test": "AreaChainTests/Domain/RuleTests.swift", "testFilter": "AreaChainTests/RuleTests",
                "metric": "wall_ms", "budget": 10, "status": "observed",
                "source": "fixture:1", "note": "fixture", "measurement": {"device": "Mac", "sampleCount": 0}
            }],
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("sampleCount" in item["detail"] for item in result["issues"]))

    def test_observed_measurement_rejects_non_string_text_fields(self):
        self.write("AreaChain/Domain/Rule.swift", "struct Rule {}\n")
        self.write("AreaChainTests/Domain/RuleTests.swift", "// fixture\n")
        required = ["device", "os", "buildConfiguration", "dataset", "sampleCount", "temperature", "metric"]
        manifest = {
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": required, "note": "fixture"},
            "entries": [{
                "id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                "test": "AreaChainTests/Domain/RuleTests.swift", "testFilter": "AreaChainTests/RuleTests",
                "metric": "wall_ms", "budget": 10, "status": "observed",
                "source": "fixture:1", "note": "fixture",
                "measurement": {field: ([] if field != "sampleCount" else 1) for field in required},
            }],
        }
        self.write("docs/performance-baselines.json", json.dumps(manifest))
        result = quality.run_performance_contract(self.root, [])
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("measurement 缺少" in item["detail"] for item in result["issues"]))

    def test_overall_status_preserves_blocked_and_strict_warning(self):
        self.assertEqual(quality.overall_status([{"status": "warning"}]), "warning")
        self.assertEqual(quality.overall_status([{"status": "warning"}], strict=True), "failed")
        self.assertEqual(quality.overall_status([{"status": "blocked"}, {"status": "warning"}]), "blocked")


if __name__ == "__main__":
    unittest.main()
