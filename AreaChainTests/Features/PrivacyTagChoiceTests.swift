import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension PrivacyInteractionTests {
    @Test(arguments: [false, true], [("en", ColorScheme.light), ("en", .dark), ("zh-Hans", .light), ("zh-Hans", .dark)])
    func tagChoicesRemainLocalThroughCancelAndReopen(creating: Bool, environment: (String, ColorScheme)) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let context = support.container.mainContext
        let store = MemoryVaultConfigurationStore()
        let keys = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: store, systemKeys: keys)
        let tags = [TagItem(name: "Synthetic ordinary 原文", sortOrder: 3),
                    TagItem(name: "密码", sortOrder: 1),
                    TagItem(name: "Synthetic private 私密", sortOrder: 2),
                    TagItem(name: "Deleted hidden", sortOrder: 0)]
        tags[2].isPrivateDiary = true
        tags[2].deletedAt = .now
        tags[3].deletedAt = .now
        for tag in tags { context.insert(tag) }
        try context.save()
        let original = tags.map { TagChoiceSnapshot($0) }
        var completed = 0
        for pass in 0..<2 {
            var dismissed = false
            let content = PrivacySetupSheet(vault: vault, tags: tags, creating: creating,
                                           onComplete: { completed += 1 }, probeSystem: false)
            let host = support.window(PrivacyButtonSheetHost(content: AnyView(content), onDismiss: { dismissed = true }),
                                      locale: environment.0, scheme: environment.1, size: NSSize(width: 520, height: 650))
            defer { SystemPageHost.release(host) }
            try await waitForTagSheet { host.attachedSheet != nil }
            let sheet = try #require(host.attachedSheet)
            try await NativeSyntaxUI.prepareFocus(in: sheet)
            // 以原初始化任务设置的私密选中值为等待条件，避免把默认空集合当成初始化结果。
            try await waitForTagSheet { (try? tagValue(tags[2].name, in: sheet)) == true }
            try await SystemPageHost.settle(sheet)
            try await Task.sleep(for: .milliseconds(350))
            #expect(try tagValue(tags[0].name, in: sheet) == false)
            #expect(try tagValue(tags[1].name, in: sheet) == creating)
            #expect(tagNodes(sheet).allSatisfy { SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String != tags[3].name })
            let frames = try [tags[1], tags[2], tags[0]].map { try SettingsButtonTestSupport.frame(tagNode($0.name, in: sheet), in: sheet) }
            #expect(frames[0].midY > frames[1].midY && frames[1].midY > frames[2].midY)
            try await SettingsButtonTestSupport.click(tagNode(tags[0].name, in: sheet), in: sheet)
            #expect(try tagValue(tags[0].name, in: sheet))
            #expect(try tagValue(tags[1].name, in: sheet) == creating)
            #expect(try tagValue(tags[2].name, in: sheet))
            try await SettingsButtonTestSupport.click(tagNode(tags[2].name, in: sheet), in: sheet)
            #expect(try !tagValue(tags[2].name, in: sheet))
            #expect(try tagValue(tags[0].name, in: sheet))
            #expect(tags.map { TagChoiceSnapshot($0) } == original && !context.hasChanges)
            try SettingsButtonTestSupport.snapshot(sheet, name: "checkbox-consumer-\(creating)-\(environment.0)-\(pass)")
            try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("alert.cancel", locale: environment.0, in: sheet), in: sheet)
            try await waitForTagSheet { host.attachedSheet == nil && dismissed }
            #expect(completed == 0 && store.value == nil && !vault.isConfigured)
            #expect(await keys.items.isEmpty)
            #expect(tags.map { TagChoiceSnapshot($0) } == original && !context.hasChanges)
        }
    }

    private func tagNodes(_ window: NSWindow) -> [NSObject] {
        SettingsButtonTestSupport.elements(window.contentView).filter {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXCheckBox"
        }
    }

    private func tagNode(_ name: String, in window: NSWindow) throws -> NSObject {
        try #require(tagNodes(window).first {
            SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == name
        })
    }

    private func tagValue(_ name: String, in window: NSWindow) throws -> Bool {
        let node = try tagNode(name, in: window)
        return try #require(SettingsButtonTestSupport.value(node, "accessibilityValue") as? NSNumber).boolValue
    }

    private func waitForTagSheet(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(condition())
    }
}

private struct TagChoiceSnapshot: Equatable {
    let id: UUID
    let name: String
    let order: Int
    let deleted: Date?
    let isPrivate: Bool

    init(_ tag: TagItem) {
        id = tag.id
        name = tag.name
        order = tag.sortOrder
        deleted = tag.deletedAt
        isPrivate = tag.isPrivateDiary
    }
}
