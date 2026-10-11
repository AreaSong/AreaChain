import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DataBackupRenderingTests {
    private static var retained: [ModelContainer] = []

    private struct Appearance: Sendable {
        var scheme: ColorScheme
        var minimum: Bool
        var language: String
    }

    private static let appearances: [Appearance] = [
        Appearance(scheme: .light, minimum: false, language: "zh-Hans"),
        Appearance(scheme: .light, minimum: true, language: "zh-Hans"),
        Appearance(scheme: .dark, minimum: false, language: "zh-Hans"),
        Appearance(scheme: .dark, minimum: true, language: "zh-Hans"),
        Appearance(scheme: .light, minimum: false, language: "en"),
        Appearance(scheme: .light, minimum: true, language: "en"),
        Appearance(scheme: .dark, minimum: false, language: "en"),
        Appearance(scheme: .dark, minimum: true, language: "en")
    ]

    @Test(arguments: appearances)
    private func settingsPrivacyAndBackupStaySeparated(_ appearance: Appearance) async throws {
        let container = try makeContainer()
        let before = try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>())
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let size = appearance.minimum ? DaybookMetrics.Window.workspaceMinSize : NSSize(width: 880, height: 640)
        let settings = try await page(SettingsView(), container: container, appearance: appearance, size: size)
        #expect(settings.contains("settings.preferences"))
        #expect(settings.contains("settings.language") && settings.contains("settings.icloud"))
        #expect(settings.contains("project.version") && settings.contains("project.support.issue"))
        #expect(settings.contains("project.support.boundary") && settings.contains("project.about.summary"))
        #expect(settings.isDisjoint(with: forbiddenOnSettings))
        let privacy = try await page(PrivacyUnlockSettingsView(vault: vault), container: container, appearance: appearance, size: size)
        #expect(privacy.contains("privacy.unlock.settings"))
        #expect(
            privacy.contains("privacy.vault.state")
                && privacy.contains("privacy.setup")
                && privacy.contains("privacy.boundary")
        )
        #expect(privacy.isDisjoint(with: [
            "dataBackup.export.json", "dataBackup.import.json",
            "dataBackup.plan.template", "dataBackup.plan.import",
            "dataBackup.export.encrypted", "dataBackup.restore.encrypted", "dataBackup.reset"
        ]))
        let backup = try await page(DataBackupView(), container: container, appearance: appearance, size: size)
        #expect(backup.contains("data.backup.page"))
        #expect(backup.contains("dataBackup.export.json") && backup.contains("dataBackup.import.json"))
        #expect(backup.contains("dataBackup.plan.template") && backup.contains("dataBackup.plan.import"))
        #expect(backup.contains("dataBackup.export.encrypted") && backup.contains("dataBackup.restore.encrypted"))
        #expect(backup.contains("dataBackup.health.ok") && !backup.contains("dataBackup.reset"))
        #expect(backup.isDisjoint(with: ["privacy.setup", "privacy.tags.manage", "privacy.autolock"]))
        #expect(!vault.isConfigured)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == before)
    }

    @Test(arguments: [ColorScheme.light, .dark], ["zh-Hans", "en"])
    func memoryFallbackShowsResetOnlyThen(scheme: ColorScheme, language: String) async throws {
        let previous = StoreHealth.shared.isUsingMemoryFallback
        defer { StoreHealth.shared.isUsingMemoryFallback = previous }
        let container = try makeContainer()
        StoreHealth.shared.isUsingMemoryFallback = true
        let appearance = Appearance(scheme: scheme, minimum: true, language: language)
        let backup = try await page(DataBackupView(), container: container, appearance: appearance, size: DaybookMetrics.Window.workspaceMinSize)
        #expect(backup.contains("dataBackup.health.warning") && backup.contains("dataBackup.reset"))
        #expect(!backup.contains("dataBackup.health.ok"))
        StoreHealth.shared.isUsingMemoryFallback = false
        let healthy = try await page(DataBackupView(), container: container, appearance: appearance, size: DaybookMetrics.Window.workspaceMinSize)
        #expect(healthy.contains("dataBackup.health.ok") && !healthy.contains("dataBackup.reset"))
    }

    private var forbiddenOnSettings: Set<String> {
        ["dataBackup.export.json", "dataBackup.import.json", "dataBackup.plan.template",
         "dataBackup.plan.import", "dataBackup.export.encrypted",
         "dataBackup.restore.encrypted", "dataBackup.reset", "privacy.setup", "privacy.tags.manage",
         "privacy.autolock", "privacy.lock.toggle"]
    }

    private func page<Content: View>(_ content: Content, container: ModelContainer, appearance: Appearance, size: NSSize) async throws -> Set<String> {
        let window = SystemPageHost.window(content, container: container, scheme: appearance.scheme, locale: appearance.language, size: size)
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        try SystemPageHost.assertContained(
            Array(ids.filter {
                $0.hasPrefix("settings.") || $0.hasPrefix("privacy.") || $0.hasPrefix("dataBackup.")
                    || $0.hasPrefix("project.") || $0 == "data.backup.page"
            }),
            in: window
        )
        return ids
    }

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retained.append(container)
        return container
    }

    @Test(arguments: [ColorScheme.light, .dark], ["zh-Hans", "en"])
    func planImportPreviewSheetRendersRecognizedItems(scheme: ColorScheme, language: String) async throws {
        let container = try makeContainer()
        let draft = try MarkdownPlanParser.parseMarkdown(
            """
            # 2026-10-11 #工作
            - [ ] 核心方案评审 !p1 @15:00 #新专题 // 准备架构对比图
              - [ ] 核对测试指标
            ## 重复事项
            - [ ] 晨间规划 @09:00 [repeat: workdays]
            ## 灵感手记
            - 导入识别预览窗口灵感 #小巧思 [pinned]
            """,
            defaultDayKey: "2026-10-11"
        )
        let workTag = ExportedTag(id: UUID(), name: "工作", sortOrder: 0)
        let snapshot = try PlanSnapshotCompiler.compile(
            draft,
            context: PlanCompileContext(existingTags: [workTag], defaultDayKey: "2026-10-11")
        )
        let preview = ImportPreviewing.preview(
            snapshot,
            existing: ExistingIDs(routines: [], todos: [], diaries: [], checks: [], tags: [workTag.id])
        )
        var tagNames: [UUID: String] = [workTag.id: workTag.name]
        for tag in snapshot.tags { tagNames[tag.id] = tag.name }
        let session = PlanImportSession(
            filename: "plan-template.md",
            snapshot: snapshot,
            preview: preview,
            tagNamesByID: tagNames,
            newTagNames: snapshot.tags.map(\.name),
            reusedTagNames: ["工作"]
        )
        let sheet = PlanImportPreviewSheet(session: session, onCancel: {}, onConfirm: {})
        let window = SystemPageHost.window(
            sheet, container: container, scheme: scheme, locale: language,
            size: NSSize(width: 640, height: 560)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("planImport.preview.sheet"))
        #expect(ids.contains("planImport.preview.confirm"))
        #expect(ids.contains("planImport.preview.cancel"))
    }
}

