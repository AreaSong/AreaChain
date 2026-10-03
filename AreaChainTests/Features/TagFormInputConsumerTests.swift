import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagFormInputConsumerTests {
    typealias Form = FormInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["todo", "routine", "recurring"])
    func originalCreationAndAssociation(hostKind: String) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let todo = TodoItem(title: "Synthetic todo", dayKey: "2026-10-03")
        let routine = DailyRoutine(title: "Synthetic routine", sortOrder: 0)
        context.insert(todo)
        context.insert(routine)
        try context.save()
        let content = Group {
            switch hostKind {
            case "todo": TodoClassificationSectionView(todo: todo, tags: [], modelContext: context)
            case "routine": RoutineClassificationSectionView(routine: routine, tags: [], modelContext: context)
            default: RecurringItemEditor()
            }
        }
        var dismissed = false
        let root = fixture.window(Group {
            if hostKind == "recurring" {
                PrivacyButtonSheetHost(content: AnyView(content.frame(width: 440, height: 820)),
                                       onDismiss: { dismissed = true })
            } else { content }
        }, size: NSSize(width: 480, height: 900))
        defer { Form.release(root) }
        let host = hostKind == "recurring" ? try await Form.sheet(in: root) : root
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        try await Native.click(Native.button("drawer.tag.add", in: host), in: host)
        let sheet = try await Form.sheet(in: host)
        let field = try #require(Form.fields(in: sheet).first)
        try await Form.enter("  common.save  ", into: field, in: sheet)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        try await Native.click(Native.button("drawer.tag.create", in: sheet), in: sheet)
        try await Form.wait { host.attachedSheet == nil }
        let fresh = ModelContext(fixture.container)
        let tags = try fresh.fetch(FetchDescriptor<TagItem>())
        let tag = try #require(tags.first)
        #expect(tags.count == 1 && tag.name == "common.save")
        #expect(TagIDList.contains(todo.tagIDs, tag.id) == (hostKind == "todo"))
        #expect(TagIDList.contains(routine.tagIDs, tag.id) == (hostKind == "routine"))
        #expect(try fresh.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
        if hostKind == "recurring" {
            // 新事项还未保存时，标签已通过原 resolveTaskTag 事务落入隔离库。
            try await Native.click(Native.button("recurring.create.cancel", in: host), in: host)
            try await Form.wait { root.attachedSheet == nil && dismissed }
            #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<TagItem>()) == 1)
            #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
        }
        #expect(todo.title == "Synthetic todo" && routine.title == "Synthetic routine")
    }

    @Test func editingClearsOnlyTagErrorAndCancelNeverCreates() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        var names: [String] = []
        var accepts = false
        let host = fixture.window(TaskDetailTagSelector(tagIDs: "", tags: [], onToggleTag: { _ in }, onCreateTag: {
            names.append($0); return accepts
        }))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await Native.click(Native.button("drawer.tag.add", in: host), in: host)
        let sheet = try await Form.sheet(in: host)
        let field = try #require(Form.fields(in: sheet).first)
        let create = try Native.button("drawer.tag.create", in: sheet)
        try await Form.enter("   ", into: field, in: sheet)
        #expect((create.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        try await Form.enter("common.save", into: field, in: sheet)
        try await Native.click(create, in: sheet)
        #expect(names == ["common.save"] && field.stringValue == "common.save")
        let error = L10n.string("save.failure.title", locale: Locale(identifier: "en"))
        #expect(Form.labels(in: sheet).contains(error))
        try await Form.enter("retry 🧪", into: field, in: sheet)
        #expect(!Form.labels(in: sheet).contains(error) && names.count == 1)
        accepts = true
        try await Native.click(create, in: sheet)
        try await Form.wait { host.attachedSheet == nil }
        #expect(names == ["common.save", "retry 🧪"])
        try await Native.click(Native.button("drawer.tag.add", in: host), in: host)
        let reopened = try await Form.sheet(in: host)
        let next = try #require(Form.fields(in: reopened).first)
        #expect(next.stringValue.isEmpty && !Form.labels(in: reopened).contains(error))
        try await Form.enter("cancel", into: next, in: reopened)
        try await Native.click(Native.button("alert.cancel", in: reopened), in: reopened)
        try await Form.wait { host.attachedSheet == nil }
        #expect(names.count == 2)
    }
}
