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
            existing = (self.root / relative).read_text() if (self.root / relative).exists() else ""
            self.write(relative, existing + f"struct {symbol} {{}}\n")
        self.write("AreaChain/Features/Quadrant/QuadrantTitleLayout.swift",
                   "struct QuadrantTitlePreview: View { var body: some View { Color.clear"
                   ".daybookSurface(floating: .rowBubble(isHovered: false, isCopied: false)) } }\n")
        contract_docs = {
            "AGENTS.md": "[路由](skill-routing.md) [目录](docs/component-catalog.md) areachain-workflow 白话请求默认行为 不把 `.cursor/plans` 当项目路线\n",
            "skill-routing.md": "areachain-workflow areachain-ui areachain-verify docs/component-catalog.md docs/quality-gates.md 用户输入契约 三个项目技能\n",
            "docs/quality-gates.md": "quality_gate.py performance-baselines.json security-static comment-contract\n",
            "docs/component-catalog.md": "TaskContentQueryReader DaybookInputShell DaybookTextField SyntaxTextField DaybookButtonStyle DaybookToggleStyle checkbox Checkbox DaybookStepper Stepper DaybookSegmentedControl DaybookSegmentOption DaybookSegmentedBar Segmented segmented DaybookPicker DaybookPickerOption formRow verbatim Picker ModernCheckbox inlineSubtask detailSubtask detailSubtaskSymbolSize Completion DaybookControlsPreview ControlsPreviewWindowController openControlsPreview settings.controlsPreview DaybookOverlaySamples daybookSurface TaskRow DayBoardList BoardFilter BoardSearch CommandCatalog DayKey AgendaProjection DayBoardPageProjection DayBoardCheckIndex DayBoardMutations ModelChanges PendingTrash BoardRowChrome BoardCommandStrip BoardSearchHitGroups WorkspaceHeaderBar WorkspaceHeaderAction WorkspaceHeaderSearchCapsule 新公共组件\n",
        }
        contract_docs["docs/component-catalog.md"] += " TaskCreateCommandAdapter claimTaskCreate requestTaskCreate UnifiedSearchTaskCreateSubmission\n"
        contract_docs["docs/component-catalog.md"] += " CommandTaskCreatePreview CommandTaskTagCatalog\n"
        contract_docs["docs/component-catalog.md"] += " TaskMutationService createCaptured CommitFacts afterPublication\n"
        contract_docs["docs/component-catalog.md"] += " TaskCreateTagCatalogReader createComposed tagCreationIDs\n"
        contract_docs["docs/component-catalog.md"] += " editTitle TaskTitleCommandPreviewReader CommandTaskTitlePreview CommandTaskTitleImpact TaskTitleCommandAdapter TaskTitleCommandEnvironment CommandTaskTitleAcceptance claimTaskTitle\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchTagSetField UnifiedSearchTaskCompositionPreview\n"
        contract_docs["docs/component-catalog.md"] += " prepareTaskTitle UnifiedSearchTaskTitlePreview UnifiedSearchTaskTitleSubmission UnifiedSearchTaskExternalFeedback\n"
        contract_docs["docs/component-catalog.md"] += " DaybookNewlinePolicy DaybookTextEditing DaybookFieldEditor DaybookSingleLineLayout\n"
        contract_docs["docs/component-catalog.md"] += " DaybookDatePicker DaybookDateCell DaybookDateCellPresentation DaybookMonthGridDay DaybookWeekdayHeader DatePicker MonthGrid DaybookHabitDateState HabitMonthGrid\n"
        contract_docs["docs/component-catalog.md"] += " DaybookWeekdayPicker WeekdayPicker TaskDetailWeekdayPicker\n"
        contract_docs["docs/component-catalog.md"] += " weekHeader WeekHeader\n"
        contract_docs["docs/component-catalog.md"] += " daybookScroll daybookScrollAssembly DaybookScrollIndicators DaybookScrollEdgeObserverNSView DaybookScrollTargetModifier\n"
        contract_docs["docs/component-catalog.md"] += " DaybookFloatingSurface SyntaxAutocompletePopup CaptureAttributesPopup rowBubble RowTitleBubble RowNoteBubble\n"
        contract_docs["docs/component-catalog.md"] += " daybookStaticCardSurface yesterdaySection centeredYesterdaySection\n"
        contract_docs["docs/component-catalog.md"] += " filterFlyout level1CategoryCard level2OptionCard\n"
        contract_docs["docs/component-catalog.md"] += " QuadrantTitlePreview\n"
        contract_docs["docs/component-catalog.md"] += " smallBackground LiveComposerPreviewHeader LiveDiaryComposerPreview\n"
        contract_docs["docs/component-catalog.md"] += " tagDetail syntaxHelp SyntaxExpandableCard\n"
        contract_docs["docs/component-catalog.md"] += " DaybookFormTextField DaybookSecureField privacy.master.input\n"
        contract_docs["docs/component-catalog.md"] += (
            " privacy.setup.master privacy.setup.master.confirmation"
            " privacy.setup.backup privacy.setup.backup.confirmation\n"
        )
        contract_docs["docs/component-catalog.md"] += (
            " readLocalSetting applyLocalSetting LocalPreferenceWriteResult LocalPreferenceStorage PreferenceObservation\n"
        )
        contract_docs["docs/component-catalog.md"] += " LocalSettingCommandAdapter LocalSettingCommandMapping CommandPreferenceBaseline\n"
        contract_docs["docs/component-catalog.md"] += (
            " FileLocalSettingCommandAdapter prepareGroup verifyCommit readLocalPreferenceRecord"
            " CommandPreferenceGroupBaseline claimPreferenceGroup\n"
        )
        contract_docs["docs/component-catalog.md"] += " requestOperationSubmit UnifiedSearchSettingSubmission\n"
        contract_docs["docs/component-catalog.md"] += " CommandTaskCompletionImpact CommandTaskTagMutation tagCandidates assignDue UnifiedSearchTaskFieldImpact\n"
        contract_docs["docs/component-catalog.md"] += (
            " CommandBatchPreview BatchCommandReader BatchCommandTransaction allObjectResultsComplete prepareBatch UnifiedSearchBatchImpact UnifiedSearchBatchSubmission"
            " CommandRoutineStatePlanning stateImpact applyRoutineState UnifiedSearchRoutineStateImpact UnifiedSearchRoutineOccurrenceDate"
            " CommandRoutineCreatePreview CommandRoutineCreateFacts RoutineCreateCommandReader prepareCreation UnifiedSearchRoutineCreateSubmission"
            " RoutineMutationService RoutineCommandReader RoutineCommandEnvironment RoutineCommandAdapter claimRoutine CommandRoutineFacts prepareRoutine UnifiedSearchRoutineSubmission"
            " SubtaskTitleEdit CreateSubtaskParams TaskFamilyCommandIdentity SubtaskCommandEnvironment"
            " SubtaskCommandAdapter claimSubtask CommandSubtaskFacts prepareSubtask UnifiedSearchSubtaskSubmission\n"
        )
        contract_docs["docs/component-catalog.md"] += (
            " TaskFieldCommandAdapter editField TaskChainCommandAdapter CommandTaskChainIdentity"
            " prepareTaskField UnifiedSearchTaskChainSubmission\n"
        )
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchSettingBackend requestFileSettingPreparation UnifiedSearchFileSettingSubmission\n"
        contract_docs["docs/component-catalog.md"] += " LocalPreferenceFileStore LocalPreferenceRecord LocalPreferencePendingWrite\n"
        contract_docs["docs/component-catalog.md"] += " LocalPreferenceLegacySource LocalPreferenceMigrationResult LocalPreferenceMigrationEvidence migrate(from reopen(from\n"
        contract_docs["docs/component-catalog.md"] += (
            " committedLocalPreferenceRecord applyLocalPreferences verifyAndReloadLocalPreferences"
            " LocalPreferencePublishedState LocalPreferenceBackendState LocalPreferenceGroupChange LocalPreferencePresentationLedger\n"
        )
        contract_docs["AGENTS.md"] += " quality-gates.md\n"
        contract_docs["docs/component-catalog.md"] += " DaybookTimePicker DaybookTimePresentation DaybookNativeTimePicker TimePicker\n"
        contract_docs["docs/component-catalog.md"] += " DiaryContentQueryReader DiaryContentQueryTagPrivacy TagContentQueryReader TaskFamilyContentQueryReader RoutineContentQueryReader ContentQueryTagNames\n"
        contract_docs["docs/component-catalog.md"] += " ContentQueryReadSession ContentQueryReadNotifications ContentQueryBodyReads\n"
        contract_docs["docs/component-catalog.md"] += " ClipboardContentQueryReader ClipboardHistoryReadResult\n"
        contract_docs["docs/component-catalog.md"] += " ImageContentQueryReads ImageContentQueryCapture\n"
        contract_docs["docs/component-catalog.md"] += " TrashContentQueryReads TrashContentQueryCapture TagUsageContentQueryReads TagUsageContentQueryCapture\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchResults UnifiedSearchController ContentQueryDisplayUpdates DaybookSearchResultText\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchInput UnifiedSearchBuffer UnifiedSearchCompletion UnifiedSearchFieldCell unifiedSearchOverlayHost\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchOperationPanel UnifiedSearchOperationPreview UnifiedSearchParameterField UnifiedSearchParameterContext\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchObjectSelectionStamp UnifiedSearchObjectField UnifiedSearchObjectPicker objectCandidate\n"
        contract_docs["docs/component-catalog.md"] += " UnifiedSearchPlanList UnifiedSearchPlanMerge UnifiedSearchPlanDependencies\n"
        contract_docs["docs/component-catalog.md"] += " CommandProtectedReference CommandDraftContentSession SealedCommandDraft CommandDraftPayload CommandDraftNativeOwner CommandProtectedTextView\n"
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

    def test_component_catalog_requires_task_capture_boundaries(self):
        self.make_project()
        self.write("AreaChain/Services/TaskMutationService.swift", "enum Other {}\n")
        self.write("AreaChain/Services/ModelChanges.swift", "enum ModelChanges {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("TaskMutationService", "createCaptured", "CommitFacts", "afterPublication"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_local_preference_boundaries(self):
        self.make_project()
        entries = (("AppPreferences", "readLocalSetting"), ("AppPreferences", "applyLocalSetting"),
                   ("LocalPreference", "LocalPreferenceWriteResult"),
                   ("LocalPreferenceDependencies", "LocalPreferenceStorage"),
                   ("PreferenceObservation", "PreferenceObservation"))
        for path, _ in entries:
            self.write(f"AreaChain/Services/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_aggregate_preference_file_boundaries(self):
        self.make_project()
        entries = (("LocalPreferenceFileStore", "LocalPreferenceFileStore"),
                   ("LocalPreferenceRecord", "LocalPreferenceRecord"),
                   ("LocalPreferenceRecord", "LocalPreferencePendingWrite"))
        for path, _ in entries:
            self.write(f"AreaChain/Services/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_preference_publication_boundaries(self):
        self.make_project()
        entries = (("AppPreferences", "committedLocalPreferenceRecord"),
                   ("AppPreferences", "applyLocalPreferences"),
                   ("AppPreferences", "verifyAndReloadLocalPreferences"),
                   ("LocalPreferencePublication", "LocalPreferencePublishedState"),
                   ("LocalPreferencePublication", "LocalPreferenceBackendState"),
                   ("LocalPreferencePublication", "LocalPreferenceGroupChange"),
                   ("LocalPreferencePresentation", "LocalPreferencePresentationLedger"))
        for path, _ in entries:
            self.write(f"AreaChain/Services/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_file_command_group_boundaries(self):
        self.make_project()
        entries = (("Services/FileLocalSettingCommandAdapter", "FileLocalSettingCommandAdapter"),
                   ("Services/FileLocalSettingCommandAdapter", "prepareGroup"),
                   ("Services/FileLocalSettingCommandAdapter", "verifyCommit"),
                   ("Services/AppPreferences", "readLocalPreferenceRecord"),
                   ("Domain/CommandPreferenceGroup", "CommandPreferenceGroupBaseline"),
                   ("Domain/CommandHandoffCoordinator", "claimPreferenceGroup"))
        for path, _ in entries:
            self.write(f"AreaChain/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_isolated_preference_migration_boundaries(self):
        self.make_project()
        entries = (("LocalPreferenceLegacySource", "LocalPreferenceLegacySource"),
                   ("LocalPreferenceLegacySource", "LocalPreferenceMigrationResult"),
                   ("LocalPreferenceMigrationEvidence", "LocalPreferenceMigrationEvidence"),
                   ("LocalPreferenceFileStore", "migrate(from"),
                   ("LocalPreferenceFileStore", "reopen(from"))
        for path, _ in entries:
            self.write(f"AreaChain/Services/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_single_setting_adapter_and_evidence(self):
        self.make_project()
        entries = (("Services", "LocalSettingCommandAdapter", "LocalSettingCommandAdapter"),
                   ("Services", "LocalSettingCommandMapping", "LocalSettingCommandMapping"),
                   ("Domain", "CommandPreferenceEvidence", "CommandPreferenceBaseline"))
        for folder, name, _ in entries:
            self.write(f"AreaChain/{folder}/{name}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_setting_submission_ui(self):
        self.make_project()
        entries = (("UnifiedSearchSettingEditing", "requestOperationSubmit"),
                   ("UnifiedSearchSettingSubmission", "UnifiedSearchSettingSubmission"))
        for name, _ in entries:
            self.write(f"AreaChain/Features/Search/{name}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_file_setting_ui(self):
        self.make_project()
        entries = (("UnifiedSearchFileSettingEditing", "UnifiedSearchSettingBackend"),
                   ("UnifiedSearchFileSettingEditing", "requestFileSettingPreparation"),
                   ("UnifiedSearchFileSettingSubmission", "UnifiedSearchFileSettingSubmission"))
        for name, _ in entries:
            self.write(f"AreaChain/Features/Search/{name}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_controls_preview(self):
        self.make_project()
        source = self.root / "AreaChain/Features/Settings/ControlsPreview/DaybookControlsPreview.swift"
        source.unlink()
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookControlsPreview" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_production_preview_wiring(self):
        self.make_project()
        for relative, symbol in workflow.COMPONENT_ENTRIES:
            if symbol in ("ControlsPreviewWindowController", "openControlsPreview", "settings.controlsPreview"):
                source = self.root / relative
                source.write_text(source.read_text().replace(symbol, "unrelated"))
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("ControlsPreviewWindowController", "openControlsPreview", "settings.controlsPreview"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_command_catalog(self):
        self.make_project()
        source = self.root / "AreaChain/Domain/CommandCatalog.swift"
        source.unlink()
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("CommandCatalog" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_task_read_adapter(self):
        self.make_project()
        self.write("AreaChain/Services/TaskContentQueryReader.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("TaskContentQueryReader" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_routine_family_read_adapters(self):
        self.make_project()
        for symbol in ("TaskFamilyContentQueryReader", "RoutineContentQueryReader", "ContentQueryTagNames"):
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{symbol}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_newline_policy_and_native_edit_boundary(self):
        self.make_project()
        path = self.root / "AreaChain/Theme/DaybookTextEditing.swift"
        original = path.read_text()
        for symbol in ("DaybookNewlinePolicy", "DaybookTextEditing"):
            with self.subTest(symbol=symbol):
                path.write_text(original.replace(symbol, "Other"))
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
        path.write_text(original)

    def test_component_catalog_requires_plain_native_editor(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookNativeTextInput.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookFieldEditor" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_verbatim_layout(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookSingleLineLayout.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookSingleLineLayout" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_diary_metadata_adapters(self):
        self.make_project()
        for symbol in ("DiaryContentQueryReader", "DiaryContentQueryTagPrivacy"):
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{symbol}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_controlled_body_dependencies(self):
        self.make_project()
        path = self.root / "AreaChain/Services/ContentQueryBodyReads.swift"
        path.write_text("struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("ContentQueryBodyReads" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_clipboard_storage_read_adapters(self):
        self.make_project()
        entries = (("ClipboardContentQueryReader", "ClipboardContentQueryReader"),
                   ("ClipboardHistoryStore", "ClipboardHistoryReadResult"))
        for filename, symbol in entries:
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{filename}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_image_metadata_adapters(self):
        self.make_project()
        for symbol in ("ImageContentQueryReads", "ImageContentQueryCapture"):
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{symbol}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_tag_usage_read_adapters(self):
        self.make_project()
        for symbol in ("TagUsageContentQueryReads", "TagUsageContentQueryCapture"):
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{symbol}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_trash_read_adapters(self):
        self.make_project()
        for symbol in ("TrashContentQueryReads", "TrashContentQueryCapture"):
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{symbol}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_search_lifecycle_adapters(self):
        self.make_project()
        entries = (("ContentQueryReadSession", "ContentQueryReadSession"),
                   ("ContentQueryReadLifecycle", "ContentQueryReadNotifications"))
        for filename, symbol in entries:
            with self.subTest(symbol=symbol):
                path = self.root / f"AreaChain/Services/{filename}.swift"
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                path.write_text(original)

    def test_component_catalog_requires_command_protection_entries(self):
        self.make_project()
        for relative, symbol in (
            ("AreaChain/Services/Privacy/CommandDraftNativeOwner.swift", "CommandDraftNativeOwner"),
            ("AreaChain/Features/Search/CommandProtectedTextView.swift", "CommandProtectedTextView"),
            ("AreaChain/Domain/CommandDraftProtection.swift", "CommandProtectedReference"),
            ("AreaChain/Services/Privacy/CommandDraftContentSession.swift", "CommandDraftContentSession"),
            ("AreaChain/Services/Privacy/SealedCommandDraft.swift", "SealedCommandDraft"),
            ("AreaChain/Services/Privacy/CommandDraftPayload.swift", "CommandDraftPayload"),
        ):
            with self.subTest(symbol=symbol):
                path = self.root / relative
                original = path.read_text()
                path.write_text("struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                path.write_text(original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_tag_read_adapter(self):
        self.make_project()
        self.write("AreaChain/Services/TagContentQueryReader.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("TagContentQueryReader" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_task_title_shared_entry_and_preview(self):
        self.make_project()
        entries = [
            ("AreaChain/Features/Search/UnifiedSearchTaskTitleEditing.swift", "prepareTaskTitle"),
            ("AreaChain/Features/Search/UnifiedSearchTaskTitlePreview.swift", "UnifiedSearchTaskTitlePreview"),
            ("AreaChain/Features/Search/UnifiedSearchTaskTitleSubmission.swift", "UnifiedSearchTaskTitleSubmission"),
            ("AreaChain/Features/Search/UnifiedSearchTaskEffectViews.swift", "UnifiedSearchTaskExternalFeedback"),
            ("AreaChain/Services/TaskTitleCommandAdapter.swift", "TaskTitleCommandAdapter"),
            ("AreaChain/Services/TaskTitleCommandEnvironment.swift", "TaskTitleCommandEnvironment"),
            ("AreaChain/Domain/CommandTaskTitleContract.swift", "CommandTaskTitleAcceptance"),
            ("AreaChain/Domain/CommandTaskTitleExecution.swift", "claimTaskTitle"),
            ("AreaChain/Services/TaskMutationService+Title.swift", "editTitle"),
            ("AreaChain/Services/TaskTitleCommandPreviewReader.swift", "TaskTitleCommandPreviewReader"),
            ("AreaChain/Domain/CommandTaskTitlePreview.swift", "CommandTaskTitlePreview"),
            ("AreaChain/Domain/CommandTaskTitleImpact.swift", "CommandTaskTitleImpact"),
        ]
        for relative, symbol in entries:
            with self.subTest(symbol=symbol):
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                self.write(relative, original)

    def test_component_catalog_requires_task_create_adapter_and_claim(self):
        self.make_project()
        for relative, symbol in [
            ("AreaChain/Features/Search/UnifiedSearchTagSetField.swift", "UnifiedSearchTagSetField"),
            ("AreaChain/Features/Search/UnifiedSearchTaskCompositionPreview.swift", "UnifiedSearchTaskCompositionPreview"),
            ("AreaChain/Services/TaskCreateTagCatalogReader.swift", "TaskCreateTagCatalogReader"),
            ("AreaChain/Services/TaskMutationService.swift", "createComposed"),
            ("AreaChain/Domain/CommandTaskCreateContract.swift", "tagCreationIDs"),
            ("AreaChain/Services/TaskCreateCommandAdapter.swift", "TaskCreateCommandAdapter"),
            ("AreaChain/Domain/CommandTaskCreatePreview.swift", "CommandTaskCreatePreview"),
            ("AreaChain/Domain/CommandTaskTagCatalog.swift", "CommandTaskTagCatalog"),
            ("AreaChain/Features/Search/UnifiedSearchTaskCreateEditing.swift", "requestTaskCreate"),
            ("AreaChain/Features/Search/UnifiedSearchTaskCreateSubmission.swift", "UnifiedSearchTaskCreateSubmission"),
            ("AreaChain/Domain/CommandTaskCreateExecution.swift", "claimTaskCreate"),
        ]:
            with self.subTest(symbol=symbol):
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))
                self.write(relative, original)

    def test_component_catalog_requires_workspace_header_contract(self):
        self.make_project()
        source = self.root / "AreaChain/Features/Workspace/WorkspaceHeaderContent.swift"
        source.unlink()
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("WorkspaceHeaderAction" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_toggle_entry(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookToggleStyle.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookToggleStyle" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_checkbox_presentation_and_metrics(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookToggleStyle.swift", "struct DaybookToggleStyle {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum DaybookMetrics {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("checkbox", "Checkbox"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_rejects_missing_stable_symbol(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookInputShell.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookInputShell" in problem["message"] for problem in result["issues"]))

    def test_component_catalog_requires_secure_field_and_password_consumers(self):
        self.make_project()
        for relative in (
            "AreaChain/Theme/DaybookSecureField.swift",
            "AreaChain/Features/Settings/PrivacyPasswordSheet.swift",
            "AreaChain/Features/Settings/PrivacySetupSheet.swift",
            "AreaChain/Features/Diary/PrivacyUnlockPresenter.swift",
        ):
            with self.subTest(relative=relative):
                original = (self.root / relative).read_text()
                self.write(relative, "struct SecureField {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any("DaybookSecureField" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_unlock_input_identifier(self):
        self.make_project()
        relative = "AreaChain/Features/Diary/PrivacyUnlockPresenter.swift"
        self.write(relative, "struct DaybookSecureField {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("privacy.master.input" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_each_setup_secure_identity(self):
        self.make_project()
        relative = "AreaChain/Features/Settings/PrivacySetupSheet.swift"
        original = (self.root / relative).read_text()
        for identity in (
            "privacy.setup.master", "privacy.setup.master.confirmation",
            "privacy.setup.backup", "privacy.setup.backup.confirmation",
        ):
            with self.subTest(identity=identity):
                self.write(relative, original.replace(f"struct {identity} {{}}\n", ""))
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(identity in item["message"] for item in result["issues"]))
        self.write(relative, original)

    def test_component_catalog_requires_form_field_and_real_consumers(self):
        self.make_project()
        for relative in (
            "AreaChain/Theme/DaybookFormTextField.swift",
            "AreaChain/Features/Workspace/TaskDetailClassificationSection.swift",
            "AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift",
        ):
            with self.subTest(relative=relative):
                original = (self.root / relative).read_text()
                self.write(relative, "struct TextField {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any("DaybookFormTextField" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_stepper_and_geometry(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookStepper.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Checkbox {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookStepper", "Stepper"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_segmented_core_adapter_geometry_motion(self):
        self.make_project()
        for path in ("DaybookSegmentedControl", "DaybookSegmentedBar", "DaybookMetrics", "DaybookChrome"):
            self.write(f"AreaChain/Theme/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookSegmentedControl", "DaybookSegmentOption", "DaybookSegmentedBar", "Segmented", "segmented"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_picker_and_geometry(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookPicker.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Checkbox {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookPicker", "DaybookPickerOption", "Picker"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_tm2_shared_boundaries(self):
        self.make_project()
        entries = (
            ("Domain/CommandTaskCompletionImpact", "CommandTaskCompletionImpact"),
            ("Domain/CommandTaskTagMutation", "CommandTaskTagMutation"),
            ("Services/TaskFieldCommandTagCandidates", "tagCandidates"),
            ("Services/TaskMutationService+Fields", "assignDue"),
            ("Features/Search/UnifiedSearchTaskFieldImpact", "UnifiedSearchTaskFieldImpact"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_bm1_boundaries(self):
        self.make_project()
        entries = (
            ("Domain/CommandBatch", "CommandBatchPreview"),
            ("Services/BatchCommandReader", "BatchCommandReader"),
            ("Services/BatchCommandTransaction", "BatchCommandTransaction"),
            ("Services/ContentQueryObjectCandidates", "allObjectResultsComplete"),
            ("Features/Search/UnifiedSearchBatchEditing", "prepareBatch"),
            ("Features/Search/UnifiedSearchBatchImpact", "UnifiedSearchBatchImpact"),
            ("Features/Search/UnifiedSearchBatchSubmission", "UnifiedSearchBatchSubmission"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_rm1_shared_boundaries(self):
        self.make_project()
        entries = (
            ("Services/RoutineMutationService", "RoutineMutationService"),
            ("Services/RoutineCommandReader", "RoutineCommandReader"),
            ("Services/RoutineCommandEnvironment", "RoutineCommandEnvironment"),
            ("Services/RoutineCommandAdapter", "RoutineCommandAdapter"),
            ("Domain/CommandRoutineExecution", "claimRoutine"),
            ("Domain/CommandRoutineFacts", "CommandRoutineFacts"),
            ("Features/Search/UnifiedSearchRoutineEditing", "prepareRoutine"),
            ("Features/Search/UnifiedSearchRoutineSubmission", "UnifiedSearchRoutineSubmission"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_rm3_state_boundaries(self):
        self.make_project()
        entries = (
            ("Domain/CommandRoutineState", "CommandRoutineStatePlanning"),
            ("Services/RoutineCommandStateReader", "stateImpact"),
            ("Services/Repositories/SwiftDataRoutineRepository+State", "applyRoutineState"),
            ("Features/Search/UnifiedSearchRoutineStateImpact", "UnifiedSearchRoutineStateImpact"),
            ("Features/Search/UnifiedSearchRoutineOccurrenceDate", "UnifiedSearchRoutineOccurrenceDate"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_rm2_creation_boundaries(self):
        self.make_project()
        entries = (
            ("Domain/CommandRoutineCreate", "CommandRoutineCreatePreview"),
            ("Domain/CommandRoutineCreateFacts", "CommandRoutineCreateFacts"),
            ("Services/RoutineCreateCommandReader", "RoutineCreateCommandReader"),
            ("Services/RoutineCreateCommandAdapter", "prepareCreation"),
            ("Features/Search/UnifiedSearchRoutineCreateSubmission", "UnifiedSearchRoutineCreateSubmission"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_tm3_shared_boundaries(self):
        self.make_project()
        entries = (
            ("Domain/SubtaskTitleEdit", "SubtaskTitleEdit"),
            ("Domain/SubtaskTitleEdit", "CreateSubtaskParams"),
            ("Services/TaskFamilyCommandIdentity", "TaskFamilyCommandIdentity"),
            ("Services/SubtaskCommandEnvironment", "SubtaskCommandEnvironment"),
            ("Services/SubtaskCommandAdapter", "SubtaskCommandAdapter"),
            ("Domain/CommandSubtaskExecution", "claimSubtask"),
            ("Domain/CommandSubtaskFacts", "CommandSubtaskFacts"),
            ("Features/Search/UnifiedSearchSubtaskEditing", "prepareSubtask"),
            ("Features/Search/UnifiedSearchSubtaskSubmission", "UnifiedSearchSubtaskSubmission"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_tm1_execution_boundaries(self):
        self.make_project()
        entries = (
            ("Services/TaskFieldCommandAdapter", "TaskFieldCommandAdapter"),
            ("Services/TaskMutationService+Fields", "editField"),
            ("Services/TaskChainCommandAdapter", "TaskChainCommandAdapter"),
            ("Domain/CommandTaskChain", "CommandTaskChainIdentity"),
            ("Features/Search/UnifiedSearchTaskFieldEditing", "prepareTaskField"),
            ("Features/Search/UnifiedSearchTaskChainSubmission", "UnifiedSearchTaskChainSubmission"),
        )
        for path, symbol in entries:
            with self.subTest(symbol=symbol):
                relative = f"AreaChain/{path}.swift"
                original = (self.root / relative).read_text()
                self.write(relative, "struct Other {}\n")
                result = workflow.check_component_catalog(self.root)
                self.write(relative, original)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_unified_operation_parameters(self):
        self.make_project()
        entries = (("Features/Search/UnifiedSearchOperationPanel", "UnifiedSearchOperationPanel"),
                   ("Features/Search/UnifiedSearchOperationPreview", "UnifiedSearchOperationPreview"),
                   ("Features/Search/UnifiedSearchParameterField", "UnifiedSearchParameterField"),
                   ("Theme/UnifiedSearchParameterContext", "UnifiedSearchParameterContext"))
        for path, _ in entries:
            self.write(f"AreaChain/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_object_selection_boundaries(self):
        self.make_project()
        entries = (("Features/Search/UnifiedSearchObjectSelection", "UnifiedSearchObjectSelectionStamp"),
                   ("Features/Search/UnifiedSearchObjectField", "UnifiedSearchObjectField"),
                   ("Features/Search/UnifiedSearchObjectPicker", "UnifiedSearchObjectPicker"),
                   ("Services/ContentQueryObjectCandidates", "objectCandidate"))
        for path, _ in entries:
            self.write(f"AreaChain/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_scroll_assembly(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookScroller.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("daybookScroll", "daybookScrollAssembly", "DaybookScrollIndicators", "DaybookScrollEdgeObserverNSView"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_scoped_scroll_bridge(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookScrollScope.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("DaybookScrollTargetModifier" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_floating_surfaces_and_consumers(self):
        self.make_project()
        entries = (("DaybookSurface", "DaybookFloatingSurface"),
                   ("SyntaxAutocompleteView", "SyntaxAutocompletePopup"),
                   ("CaptureAttributesView", "CaptureAttributesPopup"))
        for path, _ in entries:
            self.write(f"AreaChain/Theme/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_live_preview_surfaces(self):
        self.make_project()
        entries = (("DaybookSurface", "smallBackground"),
                   ("LiveComposerPreviewHeader", "LiveComposerPreviewHeader"),
                   ("LiveDiaryComposerPreview", "LiveDiaryComposerPreview"))
        for path, _ in entries:
            self.write(f"AreaChain/Theme/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_tag_detail_and_help_surfaces(self):
        self.make_project()
        entries = (("DaybookSurface", "tagDetail"), ("DaybookSurface", "syntaxHelp"),
                   ("SyntaxHelpCard", "SyntaxExpandableCard"))
        for path, _ in entries:
            self.write(f"AreaChain/Theme/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_quadrant_preview_declaration_does_not_prove_surface_adoption(self):
        self.make_project()
        path = "AreaChain/Features/Quadrant/QuadrantTitleLayout.swift"
        for body in ("Color.clear", "// .daybookSurface(floating: .rowBubble(isHovered: false, isCopied: false))\nColor.clear",
                     "Color.clear.daybookSurface(floating: .rowBubble(isHovered: false, isCopied: isCopied))"):
            with self.subTest(body=body):
                self.write(path, "struct QuadrantTitlePreview: View { var body: some View { " + body + " } }")
                result = workflow.check_component_catalog(self.root)
                self.assertEqual(result["status"], "failed")
                self.assertTrue(any("静态 rowBubble" in item["message"] for item in result["issues"]))

    def test_quadrant_preview_static_surface_accepts_line_breaks(self):
        self.make_project()
        self.write("AreaChain/Features/Quadrant/QuadrantTitleLayout.swift",
                   "struct QuadrantTitlePreview: View { var body: some View { Color.clear\n"
                   ".daybookSurface( floating: .rowBubble(\n isHovered: false,\n isCopied: false )) } }")
        self.assertEqual(workflow.check_component_catalog(self.root)["status"], "passed")

    def test_component_catalog_requires_dynamic_row_bubble_surfaces(self):
        self.make_project()
        entries = (("DaybookSurface", "rowBubble"), ("DaybookRowBubbles", "RowTitleBubble"),
                   ("DaybookRowBubbles", "RowNoteBubble"))
        for path, _ in entries:
            self.write(f"AreaChain/Theme/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_filter_flyout_surface_and_cards(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookSurface.swift", "struct Other {}\n")
        self.write("AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("filterFlyout", "level1CategoryCard", "level2OptionCard"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_static_card_and_yesterday_consumers(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookSurface.swift", "struct Other {}\n")
        self.write("AreaChain/Features/Tasks/TasksPage+Sections.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("daybookStaticCardSurface", "yesterdaySection", "centeredYesterdaySection"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_plan_editing_boundaries(self):
        self.make_project()
        entries = (("UnifiedSearchPlanList", "UnifiedSearchPlanList"),
                   ("UnifiedSearchPlanEditing", "UnifiedSearchPlanMerge"),
                   ("UnifiedSearchPlanDependencies", "UnifiedSearchPlanDependencies"))
        for path, _ in entries:
            self.write(f"AreaChain/Features/Search/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for _, symbol in entries:
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_unified_result_boundary(self):
        self.make_project()
        for path in ("Features/Search/UnifiedSearchResults", "Features/Search/UnifiedSearchController",
                     "Services/ContentQueryDisplayUpdates", "Theme/DaybookSearchResultText"):
            self.write(f"AreaChain/{path}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("UnifiedSearchResults", "UnifiedSearchController", "ContentQueryDisplayUpdates", "DaybookSearchResultText"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_unified_search_native_contract(self):
        self.make_project()
        for name in ("UnifiedSearchInput", "UnifiedSearchInputState", "UnifiedSearchNativeInput", "UnifiedSearchOverlay"):
            self.write(f"AreaChain/Theme/{name}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("UnifiedSearchInput", "UnifiedSearchBuffer", "UnifiedSearchCompletion", "UnifiedSearchFieldCell", "unifiedSearchOverlayHost"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_date_picker_cell_and_geometry(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookDatePicker.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookDateCell.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookWeekdayHeader.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookDatePicker", "DaybookDateCell", "DaybookDateCellPresentation", "DaybookMonthGridDay", "DaybookWeekdayHeader", "DatePicker", "MonthGrid", "DaybookHabitDateState", "HabitMonthGrid"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_weekday_picker_and_compatibility_adapter(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookWeekdayPicker.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Other {}\n")
        self.write("AreaChain/Features/Workspace/TaskDetailScheduleSection.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookWeekdayPicker", "WeekdayPicker", "TaskDetailWeekdayPicker"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_week_header_presentation_and_geometry(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookDateCell.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("weekHeader", "WeekHeader"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_time_picker_native_adapter_and_geometry(self):
        self.make_project()
        for name in ("DaybookTimePicker", "DaybookNativeTimePicker", "DaybookMetrics"):
            self.write(f"AreaChain/Theme/{name}.swift", "struct Other {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("DaybookTimePicker", "DaybookTimePresentation", "DaybookNativeTimePicker", "TimePicker"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_completion_presentation_and_geometry(self):
        self.make_project()
        self.write("AreaChain/Theme/ModernComponents.swift", "struct Other {}\n")
        self.write("AreaChain/Theme/DaybookMetrics.swift", "enum Checkbox {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        for symbol in ("ModernCheckbox", "inlineSubtask", "detailSubtask", "detailSubtaskSymbolSize", "Completion"):
            self.assertTrue(any(symbol in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_picker_form_layout(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookPicker.swift", "struct DaybookPicker {}\nstruct DaybookPickerOption {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("formRow" in item["message"] for item in result["issues"]))

    def test_component_catalog_requires_picker_verbatim_input(self):
        self.make_project()
        self.write("AreaChain/Theme/DaybookPicker.swift", "struct DaybookPicker {}\nstruct DaybookPickerOption {}\nenum formRow {}\n")
        result = workflow.check_component_catalog(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("verbatim" in item["message"] for item in result["issues"]))

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
