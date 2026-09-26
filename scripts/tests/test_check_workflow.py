"""用临时文档/代码和临时 Git 仓库验证守卫，不触碰应用或用户数据。"""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "check_workflow.py"
SPEC = importlib.util.spec_from_file_location("check_workflow", SCRIPT)
workflow = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(workflow)


class WorkflowCheckTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="areachain-workflow-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, relative, text):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return target

    def make_project(self):
        (self.root / "AreaChain.xcodeproj").mkdir()
        (self.root / "AreaChainTests").mkdir()
        self.write("scripts/build.sh", "# isolated fixture\n")
        self.write("AreaChain/Domain/Rule.swift", "import Foundation\nimport SwiftData\n")
        self.write("AreaChainTests/Domain/RuleTests.swift", "// fixture\n")
        for relative, symbol in workflow.COMPONENT_ENTRIES:
            self.write(relative, f"struct {symbol} {{}}\n")
        contract_docs = {
            "AGENTS.md": "[路由](skill-routing.md) [目录](docs/component-catalog.md) areachain-workflow 白话请求默认行为 不把 `.cursor/plans` 当项目路线\n",
            "skill-routing.md": "areachain-workflow areachain-ui areachain-verify docs/component-catalog.md docs/quality-gates.md 用户输入契约 三个项目技能\n",
            "docs/quality-gates.md": "quality_gate.py performance-baselines.json security-static comment-contract\n",
            "docs/component-catalog.md": "DaybookInputShell DaybookTextField SyntaxTextField DaybookButtonStyle daybookSurface TaskRow DayBoardList BoardFilter BoardSearch DayKey AgendaProjection DayBoardMutations ModelChanges 新公共组件\n",
        }
        contract_docs["AGENTS.md"] += " quality-gates.md\n"
        for name in workflow.REQUIRED_DOCS:
            self.write(name, contract_docs.get(name, "# 文档\n"))
        self.write("docs/performance-baselines.json", json.dumps({
            "schemaVersion": 1,
            "measurementPolicy": {"requiredFields": ["device", "sampleCount"], "note": "fixture"},
            "entries": [{
                "id": "rule", "scope": "AreaChain/Domain/Rule.swift",
                "test": "AreaChainTests/Domain/RuleTests.swift",
                "testFilter": "AreaChainTests/RuleTests", "metric": "wall_ms",
                "budget": 10, "status": "provisional", "source": "fixture:1", "note": "fixture"
            }]
        }))
        self.write(".github/workflows/quality.yml", """on: [push]\nworkflow_dispatch: {}\npermissions:\n  contents: read\nuses: actions/checkout@0123456789abcdef0123456789abcdef01234567\nfetch-depth: 2\nmacos-15\nbrew install swiftlint\nrun: python3 scripts/quality_gate.py --profile static --strict --format json\nrun: python3 scripts/quality_gate.py --profile swift --strict --base-ref HEAD^ --format json\n""")
        for name in workflow.SKILLS:
            content = f"---\nname: {name}\ndescription: Isolated fixture for {name}\n---\n"
            if name == "areachain-workflow":
                content += "skill-routing.md component-catalog.md areachain-verify quality-gates.md 用户无需调用本技能 skill-format\n"
            self.write(f".agents/skills/{name}/SKILL.md", content)
            self.write(f".agents/skills/{name}/agents/openai.yaml",
                       "interface:\n  display_name: Fixture\n  short_description: Isolated fixture\n")
        self.write(".gitignore", ".agents/*\n!.agents/skills/\n.agents/skills/*\n"
                   "!.agents/skills/areachain-workflow/\n"
                   "!.agents/skills/areachain-ui/\n!.agents/skills/areachain-verify/\n")
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True,
                       capture_output=True, timeout=15)

    def links(self, text):
        document = self.write("README.md", text)
        return workflow.check_links(self.root, [document], "fixture-links")

    def test_existing_file_directory_and_chinese_anchor(self):
        self.write("docs/目标.md", "## 9. 隐私保护、备份与恢复\n")
        result = self.links("[目录](docs) [正文](docs/目标.md#9-隐私保护备份与恢复)\n")
        self.assertEqual(result["status"], "passed")

    def test_missing_file_fails_with_source_line(self):
        result = self.links("# 文档\n\n[坏引用](missing.md)\n")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["issues"][0]["line"], 3)

    def test_missing_anchor_fails(self):
        self.write("target.md", "# Existing\n")
        self.assertEqual(self.links("[引用](target.md#missing)\n")["status"], "failed")

    def test_fenced_and_inline_examples_are_not_links(self):
        text = "```md\n[示例](missing.md)\n```\n`[示例](missing.md)`\n"
        self.assertEqual(self.links(text)["status"], "passed")

    def test_remote_links_are_not_fetched(self):
        with patch.object(workflow.subprocess, "run", side_effect=AssertionError("no network")):
            self.assertEqual(self.links("[远端](https://example.invalid/a#b)\n")["status"], "passed")

    def test_encoded_and_angle_wrapped_paths(self):
        self.write("docs/a b.md", "# Heading\n")
        text = "[一](docs/a%20b.md#heading) [二](<docs/a b.md>)\n"
        self.assertEqual(self.links(text)["status"], "passed")

    def test_duplicate_and_explicit_anchors(self):
        self.write("target.md", '# Same\n# Same\n<a id="custom"></a>\n')
        text = "[重复](target.md#same-1) [显式](target.md#custom)\n"
        self.assertEqual(self.links(text)["status"], "passed")

    def test_inline_code_in_heading_keeps_anchor_text(self):
        self.write("target.md", "## `ModelChanges` 保存\n")
        self.assertEqual(self.links("[标题](target.md#modelchanges-保存)\n")["status"], "passed")

    def test_heading_slug_collision_gets_next_unused_anchor(self):
        self.write("target.md", "# Same\n# Same-1\n# Same\n")
        self.assertEqual(self.links("[碰撞](target.md#same-2)\n")["status"], "passed")

    def test_root_escape_is_rejected(self):
        self.assertEqual(self.links("[外部](../outside.md)\n")["status"], "failed")

    def test_external_symlink_is_rejected_before_read(self):
        (self.root / "outside.md").symlink_to(SCRIPT)
        result = self.links("[外部](outside.md#something)\n")
        self.assertEqual(result["status"], "failed")
        self.assertIn("符号链接", result["issues"][0]["message"])

    def test_missing_required_document_fails(self):
        result = workflow.check_links(self.root, [self.root / "absent.md"], "missing")
        self.assertEqual(result["status"], "failed")

    def test_domain_rejects_direct_typed_attributed_and_conditional_imports(self):
        statements = ["import SwiftUI", "import class AppKit.NSView", "import Cocoa",
                      "@preconcurrency import AppKit", "#if false\nimport SwiftUI\n#endif"]
        for statement in statements:
            with self.subTest(statement=statement):
                self.write("AreaChain/Domain/Rule.swift", statement)
                result = workflow.check_domain(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertEqual(len(result["issues"]), 1)

    def test_domain_ignores_comments_and_strings_but_preserves_line_numbers(self):
        text = ('// import SwiftUI\n/* nested /* import AppKit */ import SwiftUI */\n'
                'let text = "import AppKit"\nlet raw = #"import SwiftUI"#\n'
                'let multi = """\nimport AppKit\n"""\nimport SwiftUI\n')
        self.write("AreaChain/Domain/Rule.swift", text)
        result = workflow.check_domain(self.root)
        self.assertEqual(len(result["issues"]), 1)
        self.assertEqual(result["issues"][0]["line"], 8)

    def test_domain_allows_existing_non_ui_imports(self):
        self.write("AreaChain/Domain/Rule.swift", "import Foundation\nimport SwiftData\n")
        self.assertEqual(workflow.check_domain(self.root)["status"], "passed")

    def test_domain_interpolation_does_not_expose_nested_string_text(self):
        statements = [r'let message = "\("import SwiftUI")"',
                      r'let message = #"\#("import AppKit")"#',
                      r'let message = "\(call("import AppKit", nested: (1 + 2)))"']
        for statement in statements:
            with self.subTest(statement=statement):
                self.write("AreaChain/Domain/Rule.swift", statement + "\nimport Foundation\n")
                self.assertEqual(workflow.check_domain(self.root)["status"], "passed")

    def test_interpolation_does_not_hide_following_real_import(self):
        self.write("AreaChain/Domain/Rule.swift", r'let message = "\("import AppKit")"' + "\nimport SwiftUI\n")
        result = workflow.check_domain(self.root)
        self.assertEqual(len(result["issues"]), 1)
        self.assertEqual(result["issues"][0]["line"], 2)

    def test_empty_domain_is_not_success(self):
        self.assertEqual(workflow.check_domain(self.root)["status"], "failed")

    def test_default_checks_pass_in_isolated_repository(self):
        self.make_project()
        report = workflow.run_checks(self.root)
        self.assertEqual(report["status"], "passed", report)
        self.assertEqual({check["name"] for check in report["checks"]},
                          {"project-identity", "project-links", "workflow-contract",
                          "component-catalog", "performance-baselines", "domain-imports",
                          "ci-contract", "skill-format", "skill-git-scope", "theme-tokens",
                          "swift-file-size"})

    def test_performance_manifest_rejects_non_object_root(self):
        self.make_project()
        self.write("docs/performance-baselines.json", "[]\n")
        result = workflow.check_performance_manifest(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertIn("顶层必须是对象", result["issues"][0]["message"])

    def test_performance_manifest_rejects_observed_without_measurement(self):
        self.make_project()
        path = self.root / "docs/performance-baselines.json"
        data = json.loads(path.read_text())
        data["entries"][0]["status"] = "observed"
        path.write_text(json.dumps(data), encoding="utf-8")
        result = workflow.check_performance_manifest(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("measurement" in problem["message"] for problem in result["issues"]))

    def test_performance_manifest_rejects_non_string_status(self):
        self.make_project()
        path = self.root / "docs/performance-baselines.json"
        data = json.loads(path.read_text())
        data["entries"][0]["status"] = []
        path.write_text(json.dumps(data), encoding="utf-8")
        result = workflow.check_performance_manifest(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("状态无效" in problem["message"] for problem in result["issues"]))

    def test_ci_contract_rejects_unpinned_checkout(self):
        self.make_project()
        path = self.root / ".github/workflows/quality.yml"
        path.write_text(path.read_text().replace("actions/checkout@0123456789abcdef0123456789abcdef01234567",
                                                   "actions/checkout@main"), encoding="utf-8")
        result = workflow.check_ci_contract(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("不可变 commit" in problem["message"] for problem in result["issues"]))

    def test_ci_contract_rejects_missing_quality_entry(self):
        self.make_project()
        path = self.root / ".github/workflows/quality.yml"
        content = path.read_text().replace(
            "scripts/quality_gate.py --profile swift --strict --base-ref HEAD^ --format json",
            "scripts/other.py",
        )
        path.write_text(content, encoding="utf-8")
        result = workflow.check_ci_contract(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("profile swift" in problem["message"] for problem in result["issues"]))

    def test_workflow_contract_rejects_missing_router_marker(self):
        self.make_project()
        self.write("skill-routing.md", "areachain-workflow\n")
        result = workflow.check_workflow_contract(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("areachain-ui" in problem["message"] for problem in result["issues"]))

    def test_component_catalog_rejects_missing_stable_symbol(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookInputShell.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookInputShell" in problem["message"] for problem in result["issues"]))

    def test_skill_format_rejects_missing_description(self):
        self.make_project()
        self.write(".agents/skills/areachain-ui/SKILL.md", "---\nname: areachain-ui\n---\n")
        result = workflow.check_skill_format(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("description" in problem["message"] for problem in result["issues"]))

    def test_skill_format_rejects_missing_display_name(self):
        self.make_project()
        self.write(".agents/skills/areachain-ui/agents/openai.yaml",
                   "interface:\n  short_description: Isolated fixture\n")
        result = workflow.check_skill_format(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("display_name" in problem["message"] for problem in result["issues"]))

    def test_accidentally_exposed_local_agent_file_fails(self):
        self.make_project()
        self.write(".gitignore", "")
        self.write(".agents/session.json", "{}")
        result = workflow.check_skill_scope(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any(problem["file"].endswith("session.json") for problem in result["issues"]))

    def test_overly_broad_ignore_hides_required_skills_and_fails(self):
        self.make_project()
        self.write(".gitignore", ".agents/\n")
        self.assertEqual(workflow.check_skill_scope(self.root)["status"], "failed")

    def test_hidden_required_skill_reference_fails_even_when_local_link_exists(self):
        self.make_project()
        reference = ".agents/skills/areachain-verify/references/checks.md"
        self.write(reference, "# Checks\n")
        self.write(".agents/skills/areachain-verify/SKILL.md", "[必需](references/checks.md)\n")
        ignore = self.root / ".gitignore"
        self.write(".gitignore", ignore.read_text() + ".agents/skills/areachain-verify/references/\n")
        report = workflow.run_checks(self.root)
        self.assertEqual(report["status"], "failed")
        scope = next(check for check in report["checks"] if check["name"] == "skill-git-scope")
        self.assertTrue(any(problem["file"].endswith(reference) for problem in scope["issues"]))

    def test_hidden_explicit_skill_resource_is_rejected(self):
        self.make_project()
        self.write(".agents/skills/areachain-verify/scripts/helper.py", "# fixture\n")
        self.write(".agents/skills/areachain-verify/SKILL.md", "[助手](scripts/helper.py)\n")
        ignore = self.root / ".gitignore"
        self.write(".gitignore", ignore.read_text() + ".agents/skills/areachain-verify/scripts/\n")
        self.assertEqual(workflow.check_skill_scope(self.root)["status"], "failed")

    def test_hidden_symlink_resource_fails_when_its_target_is_visible(self):
        self.make_project()
        target = self.write(".agents/skills/areachain-verify/scripts/real.py", "# fixture\n")
        link = target.with_name("helper.py")
        link.symlink_to("real.py")
        self.write(".agents/skills/areachain-verify/SKILL.md", "[助手](scripts/helper.py)\n")
        ignore = self.root / ".gitignore"
        self.write(".gitignore", ignore.read_text() + ".agents/skills/areachain-verify/scripts/helper.py\n")
        result = workflow.check_skill_scope(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any(problem["file"].endswith("helper.py") for problem in result["issues"]))

    def test_missing_git_reports_blocked_not_passed(self):
        with patch.object(workflow, "git", side_effect=FileNotFoundError()):
            self.assertEqual(workflow.check_skill_scope(self.root)["status"], "blocked")

    def test_undecodable_git_output_reports_blocked(self):
        error = UnicodeDecodeError("utf-8", b"\xff", 0, 1, "invalid filename")
        with patch.object(workflow, "git", side_effect=error):
            self.assertEqual(workflow.check_skill_scope(self.root)["status"], "blocked")

    def test_foreign_project_is_rejected(self):
        self.assertEqual(workflow.run_checks(self.root)["status"], "failed")

    def test_personal_scan_is_explicit_and_does_not_scan_other_skills(self):
        personal = self.root / "personal"
        self.write("personal/AGENTS.md", "# 规则\n")
        self.write("personal/skill-routing.md", "# 路由\n")
        self.write("personal/skills/areasong-development/SKILL.md", "# 技能\n")
        self.write("personal/skills/unrelated/SKILL.md", "[无关](missing.md)\n")
        result = workflow.check_links(personal, workflow.personal_docs(personal), "personal")
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["checked"], 3)

    def test_personal_anchor_cannot_read_other_skill_contents(self):
        self.make_project()
        personal = self.root / "personal"
        self.write("personal/AGENTS.md", "[其他](skills/unrelated/SKILL.md#content)\n")
        self.write("personal/skill-routing.md", "# 路由\n")
        self.write("personal/skills/areasong-development/SKILL.md", "# 技能\n")
        unrelated = self.write("personal/skills/unrelated/SKILL.md", "# Content\n")
        reads = []
        original_read = Path.read_text
        def record_read(path, *args, **kwargs):
            reads.append(path.resolve())
            return original_read(path, *args, **kwargs)
        with patch.object(workflow.Path, "read_text", record_read):
            report = workflow.run_checks(self.root, personal)
        self.assertNotIn(unrelated.resolve(), reads)
        self.assertEqual(report["status"], "failed")

    def test_default_run_never_enumerates_personal_documents(self):
        self.make_project()
        with patch.object(workflow, "personal_docs", side_effect=AssertionError("out of scope")):
            self.assertEqual(workflow.run_checks(self.root)["status"], "passed")

    def test_cli_json_and_failure_exit_code(self):
        command = [sys.executable, "-B", str(SCRIPT), "--root", str(self.root), "--format", "json"]
        failed = subprocess.run(command, capture_output=True, text=True, timeout=15)
        self.assertEqual(failed.returncode, 1)
        self.assertEqual(json.loads(failed.stdout)["status"], "failed")
        self.make_project()
        passed = subprocess.run(command, capture_output=True, text=True, timeout=15)
        self.assertEqual(passed.returncode, 0, passed.stderr)
        report = json.loads(passed.stdout)
        self.assertEqual(report["schemaVersion"], 1)
        self.assertEqual(report["status"], "passed")

    def test_theme_tokens_flags_literal_shape_color_and_layout(self):
        self.write("AreaChain/Features/Sample.swift",
                   "RoundedRectangle(cornerRadius: 4)\n"
                   "Text(\"x\").font(.system(size: 11))\n"
                   "Color.red\n"
                   ".buttonStyle(.plain)\n"
                   "DaybookTheme.ink\n"
                   "if isWorkspace {}\n"
                   ".shadow(color: .black)\n"
                   "WorkspaceLayout.headerHeight\n"
                   "if embedded { DaybookPalette.text.primary }\n"
                   "Capsule().fill(DaybookPalette.accent.base.opacity(0.2))\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertGreaterEqual(len(result["issues"]), 8)

    def test_theme_tokens_skip_control_exempt_and_token_radius(self):
        self.write("AreaChain/Features/Sample.swift",
                   "RoundedRectangle(cornerRadius: DaybookRadius.small)\n"
                   "Circle() // token-exempt: 状态点\n"
                   ".buttonStyle(.plain) // control: 整行点击\n"
                   "Divider().opacity(0.35)\n"
                   ".opacity(0)\n"
                   "let note = \"Color.red\"\n"
                   "// DaybookTheme.ink\n"
                   "WorkspaceHeaderSearchCapsule(navigation: navigation)\n")
        self.write("AreaChain/Features/Workspace/WorkspaceHeaderBar.swift",
                   "WorkspaceLayout.headerHeight\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "passed", result)

    def test_theme_tokens_embedded_layout_alone_is_allowed(self):
        self.write("AreaChain/Features/Sample.swift", "if embedded { showFilters }\n")
        self.write("AreaChain/Features/Workspace/MainSplitWorkspaceView.swift",
                   "WorkspaceLayout.maxContentWidth\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["issues"], [])

    def test_theme_tokens_reports_original_line_number(self):
        self.write("AreaChain/Features/Sample.swift", "let ok = 1\nColor.orange\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["issues"][0]["line"], 2)

    def test_theme_tokens_flags_extended_system_colors(self):
        self.write("AreaChain/Features/Sample.swift",
                   "let c1 = Color.indigo\n"
                   "let c2 = Color.mint\n"
                   "let c3 = Color.yellow\n"
                   "let c4 = Color.purple\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(len(result["issues"]), 4)

    def test_theme_tokens_control_cannot_mask_other_violations(self):
        self.write("AreaChain/Features/Sample.swift",
                   ".buttonStyle(.plain).foregroundColor(Color.red) // control: 行点击\n"
                   ".buttonStyle(.plain).font(.system(size: 11)) // control: 行点击\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(len(result["issues"]), 2)
        self.assertEqual(result["issues"][0]["line"], 1)
        self.assertEqual(result["issues"][1]["line"], 2)

    def test_theme_tokens_dynamic_opacity_is_flagged(self):
        self.write("AreaChain/Features/Sample.swift",
                   "DaybookPalette.accent.base.opacity(isHovered ? 0.8 : 0.4)\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(len(result["issues"]), 1)

    def test_swift_file_over_line_limit_fails(self):
        self.make_project()
        self.write("AreaChain/Domain/Huge.swift", "\n" * 501)
        result = workflow.check_swift_file_size(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertIn("超过 500 行", result["issues"][0]["message"])

    def test_theme_rejects_services_diary_content_dependency(self):
        self.write("AreaChain/Theme/SampleView.swift",
                   "let sensitive = DiaryContent.requiresProtection(text: \"secret\")\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DiaryContent" in issue["message"] for issue in result["issues"]))


if __name__ == "__main__":
    unittest.main()
