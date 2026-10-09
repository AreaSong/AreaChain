import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class RoutineCreateFixture {
    let base: RoutineCommandFixture
    var now = Date(timeIntervalSince1970: 1791417600)
    var calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return value
    }()
    var inputRevision = UUID()
    var environmentRevision = UUID()
    var inputProtection = CommandProtectionRequirement.ordinary
    var environmentProtection = CommandProtectionRequirement.ordinary
    var onSource: (() throws -> Void)?
    var sourceArguments: [[CommandArgument]] = []
    private(set) var environment: RoutineCommandEnvironment!
    private(set) var adapter: RoutineCommandAdapter!
    var context: ModelContext { base.context }
    var handoff: HandoffFixture { base.handoff }

    init(stateOperations: Bool = false) throws {
        base = try RoutineCommandFixture(enabled: false, stateOperations: stateOperations)
        // 墓碑也参与两个旧新增 UI 的全量末尾排序。
        base.other.deletedAt = Date(timeIntervalSince1970: 12)
        base.other.sortOrder = 30
        try context.save()
        let original = base.environment!
        environment = try .init(context: context, center: original.center, dependencies: original.dependencies,
            source: original.source, refresh: original.refresh, requestAuthorization: original.requestAuthorization,
            creation: .init(now: { [unowned self] in now }, calendar: calendar, source: { [unowned self] arguments in
                sourceArguments.append(arguments)
                try onSource?()
                return .init(input: .init(revision: inputRevision, protection: inputProtection),
                             environment: .init(revision: environmentRevision, protection: environmentProtection))
            }), stateOperations: original.stateOperations)
        adapter = .init(coordinator: handoff.coordinator, environment: environment)
    }

    func queue(title: String = "散步", mask: Int = WeekdayMask.workdays, extra: [CommandArgument] = []) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "routine.create"),
            arguments: [RoutineCommandFixture.title(title), .init(parameter: .weekdays, operation: .assign, value: .weekdays(mask))] + extra))
    }
    func preview() throws -> CommandRoutineCreatePreview {
        try adapter.prepareCreation(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandRoutineCreateAcceptance {
        let accepted = try adapter.acceptCreation(preview(), expecting: handoff.owned().lease)
        #expect(!context.hasChanges && base.count("save") == 0 && base.count("ui") == 0)
        return accepted
    }
    func submit(_ accepted: CommandRoutineCreateAcceptance) throws -> CommandRoutineCreateFacts {
        try adapter.submitCreation(accepted: accepted, expecting: handoff.owned().lease)
    }
    func stored(_ id: UUID) throws -> DailyRoutine {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try #require(SwiftDataRoutineRepository(context: reader).fetchRoutines(withID: id).first)
    }
    func snapshots() throws -> [RoutineSnapshot] {
        try context.fetch(FetchDescriptor<DailyRoutine>()).map(\.snapshot).sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
