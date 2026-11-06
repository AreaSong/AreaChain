import Foundation

/// 最小组合边界；查询返回/同步意图不产生任何操作草稿事件。
struct CommandHostSession: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    private(set) var query: ContentQuerySession
    let hostID: String

    init(page: ContentQueryPageContext) {
        query = .init(page: page)
        hostID = page.location.hostID
    }

    @discardableResult mutating func queryEvent(_ event: ContentQueryEvent) -> [ContentQueryIntent] {
        let transition = ContentQueryReducer.reduce(query, event)
        query = transition.state
        return transition.intents
    }

    mutating func presentationEvent(_ event: CommandHostPresentationEvent) {}

    var requiresUnsavedContentHandling: Bool { false }
    var isBusy: Bool { false }
    var description: String { "CommandHostSession(hostID: \(hostID))" }
    var debugDescription: String { description }

    func handoffStates(to target: Self) throws -> (source: Self, target: Self) {
        var receiver = target
        receiver.query = query.handedOff(to: target.query)
        var source = self
        source.query = query.binding == .independent(.privacyInvalidated)
            ? ContentQueryReducer.reduce(query, .privacyInvalidated).state : .init(page: query.page)
        return (source, receiver)
    }

    var handoffNativeSelections: Set<UUID> { [] }
}

enum CommandHostPresentationEvent: CaseIterable {
    case collapseCompletion, collapsePreview, clickOutside, refocus
}
