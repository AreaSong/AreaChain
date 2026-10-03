import Foundation
import Testing
@testable import AreaChain

extension UnifiedSearchResultsFixture {
    func chooseObjects(_ location: UnifiedSearchObjectLocation = .targets) async throws -> UnifiedSearchObjectSelection {
        controller.beginObjectSelection(location, source: controller.buffer)
        await controller.objectSelectionTask?.value
        return try #require(controller.objectSelection)
    }

    func acceptObjects(_ objects: [CommandObjectReference], location: UnifiedSearchObjectLocation = .targets) async throws {
        let picker = try await chooseObjects(location)
        for object in objects { controller.toggleObject(object, stamp: picker.stamp) }
        try #require(controller.acceptObjects(picker.stamp))
        await controller.objectSelectionTask?.value
    }

    nonisolated static func objectBatch(count: Int = 6) -> ContentQueryBatch {
        var batch = QueryBatchFixture.empty("/tasks")
        batch.snapshots.todos = .complete((0..<count).map { index in
            .init(id: objectID(index), title: "合成任务 \(index) · Synthetic task " + String(repeating: "long title 中文 ", count: 5),
                  isDone: false, dayKey: QuerySessionFixture.today, createdAt: TodoQueryFixture.created)
        })
        return batch
    }

    nonisolated static func objectID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
    }

    nonisolated static func object(_ index: Int) -> CommandObjectReference { .init(type: .todo, id: objectID(index)) }
}

extension ContentQueryBatch {
    static func objectBatch(count: Int = 6) -> Self { UnifiedSearchResultsFixture.objectBatch(count: count) }
}

extension CommandObjectReference {
    static func object(_ index: Int) -> Self { UnifiedSearchResultsFixture.object(index) }
}
