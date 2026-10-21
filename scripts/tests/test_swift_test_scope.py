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

    def test_extension_file_uses_its_member_names_not_the_whole_type(self):
        self.write("AreaChain/Features/Controller.swift", "final class Controller {}\n")
        self.write("AreaChain/Features/Controller+Paging.swift",
                   "extension Controller {\n    func pageForward() {\n        let local = 1\n    }\n"
                   "    private func hiddenStep() {}\n    var body: Int { 0 }\n}\nstruct Holder {\n    let mood = 0\n}\n")
        self.suite("AreaChainTests/Features/PagingTests.swift", "PagingTests", "Controller().pageForward()")
        self.suite("AreaChainTests/Features/OtherTests.swift", "OtherTests", "_ = Controller(); _ = local; _ = mood")
        self.suite("AreaChainTests/Features/HiddenTests.swift", "HiddenTests", "_ = hiddenStep; _ = body")
        # 只按扩展里非私有、非通用的成员找；被扩展类型 Controller 的其他使用者不再整体带上。
        self.assertEqual(scope.extension_members(self.root.joinpath("AreaChain/Features/Controller+Paging.swift")
                                                 .read_text()), {"pageForward"})
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

    def test_extension_block_boundaries_and_member_kinds(self):
        text = ("extension Format: Codable {}\nenum Update {\n    case setRemind\n}\n"
                "private extension Hidden {\n    func secretStep() {}\n}\n"
                "extension Store {\n    private(set) var lastSnapshot: Int { 0 }\n    enum StoreEvent {}\n"
                "    typealias Loader = Int\n    static func loadEverything() {}\n    private var cacheSlot = 0\n}\n")
        self.assertEqual(scope.extension_members(text), {"lastSnapshot", "StoreEvent", "Loader", "loadEverything"})

    def test_common_member_names_are_skipped_and_reported(self):
        self.write("AreaChain/Features/Panel+Accept.swift",
                   "extension Panel {\n    func accept() {}\n    func acceptDraftRevision() {}\n}\n")
        for index in range(3):
            self.suite(f"AreaChainTests/Features/Noise{index}Tests.swift", f"Noise{index}Tests", "x.accept()")
        self.suite("AreaChainTests/Features/DraftTests.swift", "DraftTests", "x.acceptDraftRevision()")
        with patch.object(scope, "MEMBER_FILE_LIMIT", 2):
            plan = self.plan(["AreaChain/Features/Panel+Accept.swift"])
        self.assertEqual(plan["filters"], ["AreaChainTests/DraftTests"])
        self.assertIn("常见成员名未用于匹配：accept", plan["notes"][0])
        # 通用名（如 body）同样写进说明，而不是悄悄丢弃。
        self.write("AreaChain/Features/Panel+Body.swift", "extension Panel {\n    var body: Int { 0 }\n}\n")
        plan = self.plan(["AreaChain/Features/Panel+Body.swift"])
        self.assertEqual(plan["unresolved"], ["AreaChain/Features/Panel+Body.swift"])
        self.assertIn("body", plan["notes"][0])

    def test_unmatched_file_only_compiles_and_is_reported(self):
        self.write("AreaChain/Domain/Lonely.swift", "struct Lonely {}\n")
        self.suite("AreaChainTests/Domain/ATests.swift", "ATests")
        plan = self.plan(["AreaChain/Domain/Lonely.swift"])
        # 不再按层兜底跑整层，列为无法推导，由门禁只编译并给出提示。
        self.assertEqual((plan["filters"], plan["unresolved"]), ([], ["AreaChain/Domain/Lonely.swift"]))
        self.assertIn("只编译", plan["notes"][0])

    def test_too_many_references_run_only_direct_references(self):
        self.write("AreaChain/Services/Store.swift", "final class Store {}\n")
        self.suite("AreaChainTests/Services/OneTests.swift", "OneTests", "_ = Store()")
        self.suite("AreaChainTests/Services/TwoTests.swift", "TwoTests", "_ = Store()")
        self.suite("AreaChainTests/Services/ThreeTests.swift", "ThreeTests")
        self.suite("AreaChainTests/Domain/DomainTests.swift", "DomainTests", "_ = Store()")
        with patch.object(scope, "REFERENCE_SUITE_LIMIT", 2):
            plan = self.plan(["AreaChain/Services/Store.swift"])
        # 只跑直接引用（含跨层的 DomainTests）；同层但未引用的 ThreeTests 不再被整层带上。
        self.assertEqual(plan["filters"], ["AreaChainTests/DomainTests", "AreaChainTests/OneTests",
                                           "AreaChainTests/TwoTests"])
        self.assertIn("被 3 个测试类引用，只跑直接引用", plan["notes"][0])

    def test_ui_mode_never_widens_to_layer(self):
        self.write("AreaChain/Features/Row.swift", "struct Row {}\n")
        self.write("AreaChain/Features/Card.swift", "struct Card {}\n")
        self.suite("AreaChainTests/Features/RowTests.swift", "RowTests", "_ = Row()")
        self.suite("AreaChainTests/Features/UseTests.swift", "UseTests", "_ = Row()")
        with patch.object(scope, "REFERENCE_SUITE_LIMIT", 1):
            plan = self.plan(["AreaChain/Features/Row.swift", "AreaChain/Features/Card.swift"], ui_mode=True)
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


class BackgroundRoundTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="areachain-test-rounds-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        tests = self.root / "AreaChainTests/Features"
        tests.mkdir(parents=True)
        (tests / "QuietTests.swift").write_text(
            "@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct QuietTests {\n  @Test func a() {}\n}\n",
            encoding="utf-8")
        (tests / "SplitTests.swift").write_text(
            "@Suite(.tags(.backgroundWindow))\n@MainActor struct SplitTests {\n  @Test func a() {}\n}\n",
            encoding="utf-8")
        (tests / "StackedTests.swift").write_text(
            "@Suite(.serialized, .tags(.backgroundWindow))\n@MainActor\n@available(macOS 14, *)\nstruct StackedTests {\n"
            "  @Test func a() {}\n}\n", encoding="utf-8")
        (tests / "LoudTests.swift").write_text(
            "@Suite(.serialized) @MainActor struct LoudTests {\n  @Test func a() {}\n}\n"
            "// .backgroundWindow 只在注释里出现不算\n", encoding="utf-8")

    def test_background_suites_need_the_tag_on_the_suite_declaration(self):
        self.assertEqual(scope.background_suites(self.root), {"QuietTests", "SplitTests", "StackedTests"})

    def test_full_run_splits_into_foreground_then_background(self):
        rounds = scope.split_rounds(self.root, None)
        self.assertEqual([label for label, _ in rounds], ["前台轮", "后台轮"])
        names = ["QuietTests", "SplitTests", "StackedTests"]
        self.assertEqual(rounds[0][1], [a for n in names for a in ("--skip-testing", f"AreaChainTests/{n}")])
        self.assertEqual(rounds[1][1], [a for n in names for a in ("--only-testing", f"AreaChainTests/{n}")])

    def test_filtered_run_keeps_only_needed_rounds(self):
        rounds = scope.split_rounds(self.root, ["AreaChainTests/LoudTests", "AreaChainTests/QuietTests/a()"])
        self.assertEqual(rounds, [("前台轮", ["--only-testing", "AreaChainTests/LoudTests"]),
                                  ("后台轮", ["--only-testing", "AreaChainTests/QuietTests/a()"])])
        self.assertEqual(scope.split_rounds(self.root, ["AreaChainTests/LoudTests"]),
                         [("前台轮", ["--only-testing", "AreaChainTests/LoudTests"])])

    def test_target_only_filter_is_treated_as_full_run(self):
        self.assertEqual(scope.split_rounds(self.root, ["AreaChainTests"]), scope.split_rounds(self.root, None))

    def test_empty_filters_run_nothing_and_say_so(self):
        with patch.object(quality, "run_command") as run:
            check = quality.run_swift_tests([], root=self.root)
        run.assert_not_called()
        self.assertEqual((check["status"], check["detail"]), ("passed", "没有需要运行的 Swift 测试。"))

    def test_only_background_detects_xcodebuild_filters(self):
        self.assertTrue(scope.only_background(self.root, ["-only-testing:AreaChainTests/QuietTests"]))
        self.assertTrue(scope.only_background(self.root, ["-only-testing:AreaChainTests/StackedTests/a()"]))
        for filters in ([], ["-only-testing:AreaChainTests/LoudTests"], ["-skip-testing:AreaChainTests/QuietTests"],
                        ["-only-testing:AreaChainTests/QuietTests", "-only-testing:AreaChainTests/LoudTests"],
                        ["-only-testing:AreaChainTests"]):
            with self.subTest(filters=filters):
                self.assertFalse(scope.only_background(self.root, filters))

    def test_without_background_suites_full_run_is_one_unfiltered_round(self):
        self.assertEqual(scope.split_rounds(self.root / "missing", None), [("前台轮", [])])

    def test_run_swift_tests_runs_each_round_and_fails_if_any_fails(self):
        results = iter([(0, "", "", 1.0), (65, "", "boom", 2.0)])
        with patch.object(quality, "run_command", side_effect=lambda *a, **k: next(results)) as run:
            check = quality.run_swift_tests(None, root=self.root)
        # 前台轮显式开守护，后台轮显式关，不依赖 build.sh 的自动判断。
        self.assertEqual([call.args[0][2:4] for call in run.call_args_list],
                         [["--keep-front", "--skip-testing"], ["--no-keep-front", "--only-testing"]])
        self.assertEqual(check["status"], "failed")
        self.assertIn("前台轮（需离开电脑）退出码 0", check["detail"])
        self.assertIn("后台轮（可以用电脑）退出码 65", check["detail"])


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
        self.assertEqual(self.commands(run), [["./scripts/build.sh", "qa", "--keep-front"]])
        self.assertIn("全量", checks[0]["detail"])

    def test_only_full_and_release_get_the_long_round_timeout(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            quality.swift_test_checks(self.root, [], "full", [])
            quality.swift_test_checks(self.root, [], "release", [])
            quality.swift_test_checks(self.root, [], "swift", ["AreaChainTests/FooTests"])
        self.assertEqual([call.kwargs["timeout"] for call in run.call_args_list], [10800, 10800, 1800])

    def test_explicit_only_testing_wins(self):
        with patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run:
            quality.swift_test_checks(self.root, [], "swift", ["AreaChainTests/FooTests"])
        self.assertEqual(self.commands(run), [["./scripts/build.sh", "qa", "--keep-front", "--only-testing", "AreaChainTests/FooTests"]])

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

    def test_run_profile_always_compiles_the_daily_configuration(self):
        (self.root / "AreaChainTests/Domain").mkdir(parents=True)
        (self.root / "AreaChainTests/Domain/DelegateTests.swift").write_text(
            "@Suite struct DelegateTests {\n  @Test func a() { _ = Delegate() }\n}\n", encoding="utf-8")
        with patch.object(quality, "changed_files", return_value=["AreaChain/App/Delegate.swift"]), \
             patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run, \
             patch.object(quality, "run_swiftlint", return_value=quality.gate("swiftlint", "passed")), \
             patch.object(quality, "run_workflow_check", return_value=quality.gate("workflow", "passed")), \
             patch.object(quality, "run_python_tests", return_value=quality.gate("python-tests", "passed")):
            quality.run_profile(self.root, "swift")
        # 测试在 QA 配置运行；日用配置仍单独编译一次。
        build_steps = [c[1] for c in self.commands(run) if c[0] == "./scripts/build.sh"]
        self.assertEqual(build_steps, ["build", "qa"])

    def test_run_profile_builds_when_no_tests_run(self):
        with patch.object(quality, "changed_files", return_value=["AreaChain/App/Delegate.swift"]), \
             patch.object(quality, "run_command", return_value=(0, "", "", 0.1)) as run, \
             patch.object(quality, "run_swiftlint", return_value=quality.gate("swiftlint", "passed")), \
             patch.object(quality, "run_workflow_check", return_value=quality.gate("workflow", "passed")), \
             patch.object(quality, "run_python_tests", return_value=quality.gate("python-tests", "passed")):
            report = quality.run_profile(self.root, "swift")
        self.assertIn(["./scripts/build.sh", "build"], self.commands(run))
        self.assertFalse(any(c[1] in ("test", "qa") for c in self.commands(run)))
        # 临时目录缺少性能清单等，整体状态不在此断言；只核对测试范围告警被如实带出。
        scope_checks = [c for c in report["checks"] if c["name"].startswith("swift-test")]
        self.assertEqual([(c["name"], c["status"]) for c in scope_checks], [("swift-test-scope", "warning")])


if __name__ == "__main__":
    unittest.main()
