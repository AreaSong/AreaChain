import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchBatchFixture {
    let service: BatchCommandFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }

    init(move: Bool = true, count: Int = 3, incomplete: Bool = false) throws {
        service = try BatchCommandFixture(count: count)
        service.routine.isEnabled = true
        try service.context.save()
        var batch = QueryBatchFixture.empty(move ? "/tasks Synthetic" : "/tasks")
        batch.snapshots.todos = .complete(service.todos.map(\.snapshot) + [service.other.snapshot])
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        batch.facts.metadata = .init(tagNames: Dictionary(uniqueKeysWithValues: service.tags.map { ($0.id, $0.name) }), privateTagIDs: [])
        if incomplete { batch.snapshots.subtasks = .failed }
        results = try .init(batch, pageSize: 20, privacyCenter: privacy, batchEnvironment: service.environment)
    }

    func host(_ style: Int = 0) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func command(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.clickCompositionControl("unified.objects.choose.target")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func select(_ objects: [CommandObjectReference], host: UnifiedSearchTestHost) async throws {
        let picker = try #require(controller.objectSelection)
        for target in objects {
            #expect(picker.browse.snapshot.known.contains(target))
            host.window.makeFirstResponder(try host.field)
            for _ in 0...picker.browse.snapshot.visible.count {
                if controller.objectSelection?.browse.active == target { break }
                let active = controller.objectSelection?.browse.active
                let sequence = picker.browse.snapshot.visible
                let forward = (active.flatMap(sequence.firstIndex) ?? -1) < (sequence.firstIndex(of: target) ?? 0)
                try await host.key(forward ? 125 : 126, forward ? "\u{F701}" : "\u{F700}")
            }
            try #require(controller.objectSelection?.browse.active == target)
            try await host.clickCompositionControl("unified.select." + target.searchIdentifier)
        }
        try await acceptSelection(host)
    }

    func acceptSelection(_ host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.objects.accept")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandBatchAcceptance {
        try await host.clickCompositionControl("unified.batch.prepare")
        let preview = try #require(controller.currentBatchPreview, "批量准备失败：\(controller.batchFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.batch.values")
        try host.snapshot("bm1-" + name + "-preview")
        try await host.clickCompositionControl("unified.batch.accept")
        let accepted = try #require(controller.currentBatchAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandBatchFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.batch.save") }
        let facts = try #require(controller.batchUnit?.batch)
        controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        try await host.revealSettingControlInsidePanel("unified.batch.status")
        try host.snapshot("bm1-" + name + "-result")
        return facts
    }

    func scrollDetails(_ host: UnifiedSearchTestHost, last: CommandObjectReference, name: String) async throws {
        try await host.revealSettingControlInsidePanel("unified.batch.details")
        let scrolls = ScrollNativeEvidence.views(host.window).compactMap { $0 as? NSScrollView }
            .filter { abs($0.bounds.height - 180) < 2 }
        let scroll = try #require(scrolls.count == 1 ? scrolls.first : nil)
        let original = scroll.contentView.bounds.origin
        for _ in 0..<20 {
            let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                         wheel1: -250, wheel2: 0, wheel3: 0))
            scroll.scrollWheel(with: try #require(NSEvent(cgEvent: cg)))
            try await host.settle()
        }
        #expect(scroll.contentView.bounds.origin != original)
        let node = try host.resultNode("unified.batch.remove." + last.searchIdentifier)
        let frame = try SettingsButtonTestSupport.frame(node, in: host.window)
        #expect(scroll.convert(scroll.bounds, to: nil).contains(frame))
        try host.snapshot("bm1-" + name + "-bottom")
    }
}
