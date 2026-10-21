"""Swift 定向测试推导与门禁接线的临时夹具测试；不启动 Xcode、不读取用户数据。"""

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import swift_test_scope as scope

SPEC = importlib.util.spec_from_file_location("quality_gate", SCRIPTS / "quality_gate.py")
quality = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quality)

SUITE = "import Testing\n@Suite(.serialized) @MainActor struct {name} {{\n    @Test func a() {{ {body} }}\n}}\n"


class SwiftTestScopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-test-scope-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def suite(self, relative, name, body=""):
        self.write(relative, SUITE.format(name=name, body=body))

    def plan(self, paths, **options):
        return scope.plan_swift_tests(self.root, paths, **options)

    def test_test_file_runs_suites_declared_or_extended_in_it(self):
        self.write("AreaChainTests/Domain/ClipTests.swift",
                   "@Suite struct ClipRulesTests {\n  @Test func a() {}\n}\nstruct ClipStoreTests {\n  @Test func b() {}\n"
                   "  struct NestedTests {}\n}\nprivate struct Probe {}\n")
        self.write("AreaChainTests/Features/HelpKeyboardTests.swift",
                   "extension HelpSurfaceTests {\n    @Test func key() {}\n}\nprivate final class Responder {}\n")
        plan = self.plan(["AreaChainTests/Domain/ClipTests.swift", "AreaChainTests/Features/HelpKeyboardTests.swift"])
        self.assertEqual(plan["filters"], ["AreaChainTests/ClipRulesTests", "AreaChainTests/ClipStoreTests",
                                           "AreaChainTests/HelpSurfaceTests"])
        self.assertEqual(plan["unresolved"], [])

    def test_source_file_uses_same_name_and_referencing_suites(self):
        self.write("AreaChain/Domain/DayKey.swift", "struct DayKey {}\nenum DayKeyFormat {}\n")
        self.suite("AreaChainTests/Domain/DayKeyTests.swift", "DayKeyTests")
        self.suite("AreaChainTests/Services/BoardTests.swift", "BoardTests", "_ = DayKeyFormat.self")
        self.suite("AreaChainTests/Services/OtherTests.swift", "OtherTests", "_ = DayKeyed.self")
        plan = self.plan(["AreaChain/Domain/DayKey.swift"])
        self.assertEqual(plan["filters"], ["AreaChainTests/BoardTests", "AreaChainTests/DayKeyTests"])
        self.assertEqual(plan["notes"], [])

    def test_fixture_files_are_followed_one_hop(self):
        self.write("AreaChain/Features/Router.swift", "final class Router {}\n")
        self.write("AreaChainTests/Features/RouterFixture.swift", "final class RouterFixture { let r = Router() }\n")
        self.suite("AreaChainTests/Features/PageTests.swift", "PageTests", "_ = RouterFixture()")
        self.assertEqual(self.plan(["AreaChain/Features/Router.swift"])["filters"], ["AreaChainTests/PageTests"])
        # 改夹具本身也按引用推导，不再整体回退全量。
        self.assertEqual(self.plan(["AreaChainTests/Features/RouterFixture.swift"])["filters"],
                         ["AreaChainTests/PageTests"])

    def test_extension_file_maps_to_the_extended_app_type(self):
        self.write("AreaChain/Features/Controller.swift", "final class Controller {}\n")
        self.write("AreaChain/Features/Controller+Paging.swift",
                   "extension Controller {\n    func page() {}\n}\nextension String {}\n")
        self.suite("AreaChainTests/Features/PagingTests.swift", "PagingTests", "_ = Controller()")
        self.suite("AreaChainTests/Features/TextTests.swift", "TextTests", "_ = String()")
        plan = self.plan(["AreaChain/Features/Controller+Paging.swift"])
        self.assertEqual(plan["filters"], ["AreaChainTests/PagingTests"])

    def test_fixture_declared_inside_a_suite_file_is_followed(self):
        self.write("AreaChain/Services/Adapter.swift", "final class Adapter {}\n")
        self.write("AreaChainTests/Services/VaultTests.swift",
                   "actor FakeKeys { let a = Adapter() }\nprivate struct LocalProbe {}\n"
                   "@Suite struct VaultTests {\n    @Test func a() {}\n}\n")
        self.suite("AreaChainTests/Services/LockTests.swift", "LockTests", "_ = FakeKeys()")
        self.suite("AreaChainTests/Services/ProbeTests.swift", "ProbeTests", "_ = LocalProbe()")
        self.assertEqual(self.plan(["AreaChain/Services/Adapter.swift"])["filters"],
                         ["AreaChainTests/LockTests", "AreaChainTests/VaultTests"])
        # 改套件文件本身时，也带上经它的共享夹具受影响的套件；private 类型不外溢。
        self.assertEqual(self.plan(["AreaChainTests/Services/VaultTests.swift"])["filters"],
                         ["AreaChainTests/LockTests", "AreaChainTests/VaultTests"])

    def test_resources_map_to_tests_reading_them_or_are_reported(self):
        self.suite("AreaChainTests/Domain/CopyTests.swift", "CopyTests", 'let f = "Localizable.xcstrings"')
        plan = self.plan(["AreaChain/Resources/Localizable.xcstrings", "AreaChain/App/AreaChain.entitlements"])
        self.assertEqual(plan["filters"], ["AreaChainTests/CopyTests"])
        self.assertEqual(plan["unresolved"], ["AreaChain/App/AreaChain.entitlements"])

    def test_unmatched_file_falls_back_to_its_layer_with_a_note(self):
        self.write("AreaChain/Domain/Lonely.swift", "struct Lonely {}\n")
        self.suite("AreaChainTests/Domain/ATests.swift", "ATests")
        self.suite("AreaChainTests/Services/BTests.swift", "BTests")
        plan = self.plan(["AreaChain/Domain/Lonely.swift"])
        self.assertEqual(plan["filters"], ["AreaChainTests/ATests"])
        self.assertIn("改跑 Domain 层", plan["notes"][0])

    def test_too_many_references_fall_back_to_layer(self):
        self.write("AreaChain/Services/Store.swift", "final class Store {}\n")
        self.suite("AreaChainTests/Services/OneTests.swift", "OneTests", "_ = Store()")
        self.suite("AreaChainTests/Services/TwoTests.swift", "TwoTests", "_ = Store()")
        self.suite("AreaChainTests/Services/ThreeTests.swift", "ThreeTests")
        self.suite("AreaChainTests/Domain/DomainTests.swift", "DomainTests", "_ = Store()")
        with patch.object(scope, "REFERENCE_SUITE_LIMIT", 2):
            plan = self.plan(["AreaChain/Services/Store.swift"])
        # 层目录兜住间接使用，跨层的直接引用（DomainTests）也保留。
        self.assertEqual(plan["filters"], ["AreaChainTests/DomainTests", "AreaChainTests/OneTests",
                                           "AreaChainTests/ThreeTests", "AreaChainTests/TwoTests"])
        self.assertIn("被 3 个测试类引用，另加跑 Services 层", plan["notes"][0])

    def test_ui_mode_never_widens_to_layer(self):
        self.write("AreaChain/Features/Row.swift", "struct Row {}\n")
        self.write("AreaChain/Features/Card.swift", "struct Card {}\n")
        self.suite("AreaChainTests/Features/RowTests.swift", "RowTests", "_ = Row()")
        self.suite("AreaChainTests/Features/UseTests.swift", "UseTests", "_ = Row()")
        with patch.object(scope, "REFERENCE_SUITE_LIMIT", 1):
            plan = self.plan(["AreaChain/Features/Row.swift", "AreaChain/Features/Card.swift"], layer_fallback=False)
        self.assertEqual(plan["filters"], ["AreaChainTests/RowTests"])
        self.assertEqual(plan["unresolved"], ["AreaChain/Features/Card.swift"])

    def test_unmappable_paths_are_reported_not_widened_to_full(self):
        self.write("AreaChain/App/Delegate.swift", "final class Delegate {}\n")
        self.suite("AreaChainTests/Domain/ATests.swift", "ATests")
        plan = self.plan(["AreaChain/App/Delegate.swift", "AreaChain.xcodeproj/project.pbxproj"])
        self.assertEqual(plan["filters"], [])
        self.assertEqual(plan["unresolved"], ["AreaChain.xcodeproj/project.pbxproj", "AreaChain/App/Delegate.swift"])

    def test_deleted_test_file_needs_no_run_and_large_changes_still_resolve(self):
        self.assertEqual(self.plan(["AreaChainTests/Domain/GoneTests.swift"]),
                         {"filters": [], "notes": [], "unresolved": []})
        paths = []
        for index in range(8):
            self.write(f"AreaChain/Domain/File{index}.swift", f"struct File{index} {{}}\n")
            self.suite(f"AreaChainTests/Domain/File{index}Tests.swift", f"File{index}Tests")
            paths.append(f"AreaChain/Domain/File{index}.swift")
        self.assertEqual(len(self.plan(paths)["filters"]), 8)


class SwiftTestChecksTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-test-checks-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "AreaChain/App").mkdir(parents=True)
        (self.root / "AreaChain/App/Delegate.swift").write_text("final class Delegate {}\n", encoding="utf-8")

    def commands(self, run):
        return [call.args[0] for call in run.call_args_list]

    def test_full_profile_is_the_only_unfiltered_run(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            checks = quality.swift_test_checks(self.root, ["AreaChain/App/Delegate.swift"], "full", [])
        self.assertEqual(self.commands(run), [["./scripts/build.sh", "test"]])
        self.assertIn("全量", checks[0]["detail"])

    def test_explicit_only_testing_wins(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            quality.swift_test_checks(self.root, [], "swift", ["AreaChainTests/FooTests"])
        self.assertEqual(self.commands(run), [["./scripts/build.sh", "test", "--only-testing", "AreaChainTests/FooTests"]])

    def test_unresolved_swift_change_warns_and_runs_no_tests(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            checks = quality.swift_test_checks(self.root, ["AreaChain/App/Delegate.swift"], "swift", [])
        self.assertEqual(self.commands(run), [])
        self.assertEqual([(c["name"], c["status"]) for c in checks], [("swift-test-scope", "warning")])
        self.assertIn("--profile full", checks[0]["detail"])

    def test_ui_without_related_tests_is_exempt(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            checks = quality.swift_test_checks(self.root, ["AreaChain/App/Delegate.swift"], "ui", [])
        self.assertEqual(self.commands(run), [])
        self.assertEqual([(c["name"], c["status"]) for c in checks], [("swift-tests", "passed")])

    def test_run_profile_builds_when_no_tests_run(self):
        with patch.object(quality, "changed_files", return_value=["AreaChain/App/Delegate.swift"]), \
             patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run, \
             patch.object(quality, "run_swiftlint", return_value=quality.gate("swiftlint", "passed")), \
             patch.object(quality, "run_workflow_check", return_value=quality.gate("workflow", "passed")), \
             patch.object(quality, "run_python_tests", return_value=quality.gate("python-tests", "passed")):
            report = quality.run_profile(self.root, "swift")
        self.assertIn(["./scripts/build.sh", "build"], self.commands(run))
        self.assertNotIn(["./scripts/build.sh", "test"], self.commands(run))
        # 临时目录缺少性能清单等，整体状态不在此断言；只核对测试范围告警被如实带出。
        scope_checks = [c for c in report["checks"] if c["name"].startswith("swift-test")]
        self.assertEqual([(c["name"], c["status"]) for c in scope_checks], [("swift-test-scope", "warning")])


if __name__ == "__main__":
    unittest.main()
