import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 真实表单只走本地编辑与取消；配置直接注入，不创建或解锁保险箱。
@Suite(.serialized) @MainActor
struct PrivacySetupToggleTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func initialShapeAndModeRules(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for mode in [(true, false), (false, true), (true, true), (false, false)] {
            let fixture = try SetupFixture(support, configured: mode.1)
            let host = fixture.host(creating: mode.0, locale: locale, scheme: scheme)
            defer { SystemPageHost.release(host) }
            let sheet = try await fixture.ready(host)
            let legacy = try control("privacy.legacy.include", locale: locale, in: sheet)
            #expect(try checked(legacy) == mode.0)
            let hasMethods = mode.0 && !mode.1
            for key in ["privacy.methods.system", "privacy.methods.master"] {
                #expect((find(key, locale: locale, in: sheet) != nil) == hasMethods)
            }
            if hasMethods {
                let system = try control("privacy.methods.system", locale: locale, in: sheet)
                let master = try control("privacy.methods.master", locale: locale, in: sheet)
                #expect(try checked(system) && !checked(master))
                let frames = try [system, master, legacy].map { try SettingsButtonTestSupport.frame($0, in: sheet) }
                #expect(frames[0].midY > frames[1].midY && frames[1].midY > frames[2].midY)
                try SettingsButtonTestSupport.assertBounds([system, master, legacy], in: sheet)
            }
            #expect(try #require(sheet.contentView).bounds.width == 480)
            try SettingsButtonTestSupport.snapshot(sheet, name: "privacy-toggle-initial-\(mode.0)-\(mode.1)-\(locale)-\(scheme)")
            try await fixture.unchanged()
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func choicesValidationDraftsAndCancel(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false)
        for pass in 0..<2 {
            let host = fixture.host(creating: true, locale: locale, scheme: scheme)
            defer { SystemPageHost.release(host) }
            let sheet = try await fixture.ready(host)
            try expectCount(1, locale: locale, in: sheet)
            #expect(fields(sheet).count == 2 && fields(sheet).allSatisfy { $0.stringValue.isEmpty })
            try expectApply(false, locale: locale, in: sheet)
            try await toggle("privacy.legacy.include", locale: locale, in: sheet)
            try expectCount(0, locale: locale, in: sheet)
            #expect(fields(sheet).isEmpty)
            try expectApply(true, locale: locale, in: sheet)
            try await toggle("privacy.methods.system", locale: locale, in: sheet)
            try expectApply(false, locale: locale, in: sheet)
            #expect(!hasText("privacy.system.only.warning", locale: locale, in: sheet))
            try await toggle("privacy.methods.master", locale: locale, in: sheet)
            try await validateMaster(locale: locale, in: sheet)
            try await toggle("privacy.methods.system", locale: locale, in: sheet)
            #expect(try checked(control("privacy.methods.master", locale: locale, in: sheet)))
            try SetupSecureTestSupport.expectValues([.master: "synthetic-password", .masterConfirmation: "synthetic-password"], in: sheet)
            try await toggle("privacy.methods.master", locale: locale, in: sheet)
            #expect(fields(sheet).isEmpty && hasText("privacy.system.only.warning", locale: locale, in: sheet))
            try await toggle("privacy.methods.master", locale: locale, in: sheet)
            try SetupSecureTestSupport.expectValues([.master: "synthetic-password", .masterConfirmation: "synthetic-password"], in: sheet)
            try await validateLegacyDrafts(locale: locale, in: sheet)
            let tag = try tagNode(fixture.tag.name, in: sheet)
            #expect(try checked(tag))
            try await fixture.unchanged()
            try SettingsButtonTestSupport.snapshot(sheet, name: "privacy-toggle-expanded-\(locale)-\(scheme)-\(pass)")
            try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("alert.cancel", locale: locale, in: sheet), in: sheet)
            try await fixture.wait { host.attachedSheet == nil && fixture.dismissed }
            try await fixture.unchanged()
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func managementCancelRestoresLegacyDefault(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: true)
        for _ in 0..<2 {
            let host = fixture.host(creating: false, locale: locale, scheme: scheme)
            defer { SystemPageHost.release(host) }
            let sheet = try await fixture.ready(host)
            #expect(try !checked(control("privacy.legacy.include", locale: locale, in: sheet)))
            #expect(fields(sheet).isEmpty)
            try expectApply(true, locale: locale, in: sheet)
            try await toggle("privacy.legacy.include", locale: locale, in: sheet)
            try expectCount(1, locale: locale, in: sheet)
            try expectApply(false, locale: locale, in: sheet)
            try await enter("synthetic-backup", field: .backup, in: sheet)
            try await enter("synthetic-backup", field: .backupConfirmation, in: sheet)
            try expectApply(true, locale: locale, in: sheet)
            #expect(try checked(tagNode(fixture.tag.name, in: sheet)))
            try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("alert.cancel", locale: locale, in: sheet), in: sheet)
            try await fixture.wait { host.attachedSheet == nil && fixture.dismissed }
            try await fixture.unchanged()
        }
    }

    private func validateMaster(locale: String, in sheet: NSWindow) async throws {
        try expectApply(false, locale: locale, in: sheet)
        try await enter("short", field: .master, in: sheet)
        try await enter("short", field: .masterConfirmation, in: sheet)
        try expectApply(false, locale: locale, in: sheet)
        try await enter("synthetic-password", field: .master, in: sheet)
        try expectApply(false, locale: locale, in: sheet)
        try await enter("synthetic-password", field: .masterConfirmation, in: sheet)
        try expectApply(true, locale: locale, in: sheet)
    }

    private func validateLegacyDrafts(locale: String, in sheet: NSWindow) async throws {
        try await toggle("privacy.legacy.include", locale: locale, in: sheet)
        try expectCount(1, locale: locale, in: sheet)
        #expect(fields(sheet).count == 4)
        try expectApply(false, locale: locale, in: sheet)
        try await enter("synthetic-backup", field: .backup, in: sheet)
        try await enter("different-backup", field: .backupConfirmation, in: sheet)
        try expectApply(false, locale: locale, in: sheet)
        try await enter("synthetic-backup", field: .backupConfirmation, in: sheet)
        try expectApply(true, locale: locale, in: sheet)
        try await toggle("privacy.legacy.include", locale: locale, in: sheet)
        try expectCount(0, locale: locale, in: sheet)
        try await toggle("privacy.legacy.include", locale: locale, in: sheet)
        try SetupSecureTestSupport.expectValues([.master: "synthetic-password", .masterConfirmation: "synthetic-password",
                                               .backup: "synthetic-backup", .backupConfirmation: "synthetic-backup"], in: sheet)
        try expectApply(true, locale: locale, in: sheet)
        for field in fields(sheet) {
            try await SettingsButtonTestSupport.reveal(field, in: sheet)
            let rect = field.alignmentRect(forFrame: field.frame)
            let visible = field.superview!.convert(rect, to: nil)
            #expect(visible.minX >= 24 && visible.maxX <= 456)
        }
        let help = try textNode("privacy.backup.password.help", locale: locale, in: sheet)
        try await SettingsButtonTestSupport.reveal(help, in: sheet)
        try SettingsButtonTestSupport.assertBounds([help, SettingsButtonTestSupport.button("privacy.apply", locale: locale, in: sheet)], in: sheet)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func disabledSheetRejectsEachChoice(locale: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false)
        let host = fixture.host(creating: true, locale: locale, scheme: .light, disabled: true)
        defer { SystemPageHost.release(host) }
        let sheet = try await fixture.ready(host)
        for key in ["privacy.methods.system", "privacy.methods.master", "privacy.legacy.include"] {
            let node = try control(key, locale: locale, in: sheet)
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            let before = try checked(node)
            try await toggle(key, locale: locale, in: sheet)
            #expect(try checked(control(key, locale: locale, in: sheet)) == before)
        }
        try await fixture.unchanged()
    }

    private func toggle(_ key: String, locale: String, in window: NSWindow) async throws {
        let node = try control(key, locale: locale, in: window)
        try await SettingsButtonTestSupport.reveal(node, in: window)
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        try SettingsButtonTestSupport.assertBounds([node], in: window)
        // 点在文字尾部而非方框上，验证整个标签点击区。
        let point = NSPoint(x: rect.maxX - 8, y: rect.midY)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    private func tagNode(_ name: String, in sheet: NSWindow) throws -> NSObject {
        try #require(SettingsButtonTestSupport.elements(sheet.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXCheckBox"
                && SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == name
        })
    }

    private func expectApply(_ enabled: Bool, locale: String, in sheet: NSWindow) throws {
        let node = try SettingsButtonTestSupport.button("privacy.apply", locale: locale, in: sheet)
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == enabled)
    }

    private func expectCount(_ count: Int, locale: String, in sheet: NSWindow) throws {
        let title = L10n.format("privacy.migration.count", locale: Locale(identifier: locale), count)
        #expect(SettingsButtonTestSupport.elements(sheet.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == title
                || SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == title
        })
    }

    private func textNode(_ key: String, locale: String, in sheet: NSWindow) throws -> NSObject {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return try #require(SettingsButtonTestSupport.elements(sheet.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == title
                || SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == title
        })
    }

    private func hasText(_ key: String, locale: String, in sheet: NSWindow) -> Bool {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return SettingsButtonTestSupport.elements(sheet.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == title
                || SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == title
        }
    }

    private func fields(_ sheet: NSWindow) -> [NSSecureTextField] {
        SettingsButtonTestSupport.elements(sheet.contentView).compactMap { $0 as? NSSecureTextField }.sorted {
            $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY
        }
    }

    private func enter(_ text: String, field: SetupSecureTestSupport.Field, in sheet: NSWindow) async throws {
        try await SetupSecureTestSupport.enter(text, field: field, in: sheet)
    }

    private func find(_ key: String, locale: String, in window: NSWindow) -> NSObject? {
        let label = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXCheckBox"
                && SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == label
        }
    }

    private func control(_ key: String, locale: String, in window: NSWindow) throws -> NSObject {
        try #require(find(key, locale: locale, in: window), "缺少严格本地化复选框：\(key)")
    }

    private func checked(_ node: NSObject) throws -> Bool {
        try #require(SettingsButtonTestSupport.value(node, "accessibilityValue") as? NSNumber).boolValue
    }
}

@MainActor
final class SetupFixture {
    let support: SettingsButtonTestSupport
    let store: MemoryVaultConfigurationStore
    let keys = FakeSystemVaultKeys()
    let vault: PrivacyVault
    let tag: TagItem
    let note: DiaryEntry
    let original: PrivacyConfiguration?
    let originalNote: DiarySnapshot
    let originalTagID: UUID
    let originalPreferences: NSDictionary
    let originalModelCounts: [Int]
    var completed = 0
    var dismissed = false

    init(_ support: SettingsButtonTestSupport, configured: Bool, tagged: Bool = false) throws {
        self.support = support
        original = configured ? PrivacyConfiguration(vaultID: UUID(), systemKeyID: UUID(),
                                                     verification: Data(repeating: 0, count: 28)) : nil
        store = MemoryVaultConfigurationStore(original)
        vault = PrivacyVault(store: store, systemKeys: keys)
        tag = TagItem(name: "Synthetic private 私密", sortOrder: 0)
        tag.isPrivateDiary = true
        note = DiaryEntry(text: "Synthetic legacy #密码", dayKey: "2026-09-15")
        if tagged { note.tagIDs = TagIDList.encode([tag.id]) }
        support.container.mainContext.insert(tag)
        support.container.mainContext.insert(note)
        try support.container.mainContext.save()
        originalNote = note.snapshot
        originalTagID = tag.id
        originalPreferences = (support.defaults.persistentDomain(forName: support.suite) ?? [:]) as NSDictionary
        originalModelCounts = try Self.modelCounts(in: support.container.mainContext)
    }

    func host(creating: Bool, locale: String, scheme: ColorScheme, disabled: Bool = false) -> NSWindow {
        dismissed = false
        let content = PrivacySetupSheet(vault: vault, tags: [tag], creating: creating,
            onComplete: { self.completed += 1 }, probeSystem: false).disabled(disabled)
        return support.window(PrivacyButtonSheetHost(content: AnyView(content), onDismiss: { self.dismissed = true }),
                              locale: locale, scheme: scheme, size: NSSize(width: 520, height: 650))
    }

    func ready(_ host: NSWindow) async throws -> NSWindow {
        try await wait { host.attachedSheet != nil }
        let sheet = try #require(host.attachedSheet)
        try await NativeSyntaxUI.prepareFocus(in: sheet)
        // 私密标签由 task 选中，以它确认初始化完成，之后等待 sheet 位移稳定。
        try await wait {
            SettingsButtonTestSupport.elements(sheet.contentView).contains {
                SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == self.tag.name
                    && (SettingsButtonTestSupport.value($0, "accessibilityValue") as? NSNumber)?.boolValue == true
            }
        }
        var previous = sheet.frame
        var stable = 0
        try await wait {
            stable = sheet.frame == previous ? stable + 1 : 0
            previous = sheet.frame
            return stable >= 4
        }
        try await SystemPageHost.settle(sheet)
        return sheet
    }

    func unchanged() async throws {
        #expect(completed == 0 && store.value == original && vault.configuration == original)
        #expect(store.pendingSystemKeyIDs.isEmpty && !vault.isAuthenticating && vault.authenticatedAt == nil)
        #expect(await keys.items.isEmpty)
        #expect(await keys.pendingRead == nil)
        #expect(tag.name == "Synthetic private 私密" && tag.isPrivateDiary && tag.deletedAt == nil)
        #expect(note.text == "Synthetic legacy #密码" && note.tagIDs == originalNote.tagIDs && !note.hasProtectedContent)
        #expect(note.snapshot == originalNote && note.encryptedText == nil && note.privacyVaultID == nil)
        #expect(tag.id == originalTagID && tag.sortOrder == 0 && tag.colorToken == TagColorToken.default.rawValue)
        #expect(vault.generation == 0 && vault.revision == 0 && !vault.isUnlocked)
        #expect(originalPreferences == (support.defaults.persistentDomain(forName: support.suite) ?? [:]) as NSDictionary)
        #expect(!support.container.mainContext.hasChanges)
        #expect(try Self.modelCounts(in: support.container.mainContext) == originalModelCounts)
    }

    private static func modelCounts(in context: ModelContext) throws -> [Int] {
        // 原配置矩阵复用同一内存库，各夹具以建立时的数量为基线，不能假定库里永远只有一条。
        try [context.fetchCount(FetchDescriptor<DiaryEntry>()), context.fetchCount(FetchDescriptor<TagItem>()),
             context.fetchCount(FetchDescriptor<AttachmentItem>()), context.fetchCount(FetchDescriptor<TodoItem>()),
             context.fetchCount(FetchDescriptor<SubtaskItem>()), context.fetchCount(FetchDescriptor<DailyRoutine>()),
             context.fetchCount(FetchDescriptor<RoutineCheck>())]
    }

    func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(60)) }
        try #require(condition())
    }
}
