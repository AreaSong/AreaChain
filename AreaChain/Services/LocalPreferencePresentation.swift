import Foundation
import Observation

typealias LocalPreferencePresentationStep = CommandPreferencePresentationStep

struct LocalPreferencePresentation: Equatable, Sendable {
    let change: LocalPreferenceGroupChange
    var appearance: LocalPreferencePresentationStep
    var event: LocalPreferencePresentationStep
    var supersededFields: Set<LocalPreferenceField> = []
}

/// 仅保存本实例的展示事实与修订，不持有可编辑值或执行队列。重试从当前发布状态取值。
@Observable @MainActor
final class LocalPreferencePresentationLedger {
    private var reports: [UUID: LocalPreferencePresentation] = [:]
    @ObservationIgnored private let effects: LocalPreferenceEffects

    init(effects: LocalPreferenceEffects) { self.effects = effects }

    func report(for commitID: UUID) -> LocalPreferencePresentation? { reports[commitID] }

    func begin(_ change: LocalPreferenceGroupChange) {
        reports[change.commitID] = LocalPreferencePresentation(change: change,
            appearance: change.fields.contains(.appearance) ? .pending : .notCalled, event: .pending)
    }

    @discardableResult
    func apply(_ commitID: UUID, current: () -> LocalPreferenceRecord?) -> LocalPreferencePresentation? {
        guard var report = reports[commitID] else { return nil }
        if report.appearance == .pending || report.appearance == .threw {
            if let record = current(), report.change.currentFields(in: record).contains(.appearance) {
                report.appearance = call { try effects.applyAppearance(record.values.appearance) }
            } else {
                report.appearance = .superseded
                report.supersededFields.insert(.appearance)
            }
        }
        reports[commitID] = report
        // 外观抛错不阻止独立事件；事件迟到时仅刷新仍有效的字段，消费者继续读取当前值。
        if report.event == .pending || report.event == .threw {
            let validFields = report.change.currentFields(in: current())
            report.supersededFields.formUnion(report.change.fields.subtracting(validFields))
            if validFields.isEmpty {
                report.event = .superseded
            } else {
                report.event = call { try effects.post(Notification(name: .localPreferenceDidChange, object: report.change)) }
            }
        }
        reports[commitID] = report
        return report
    }

    private func call(_ action: () throws -> Void) -> LocalPreferencePresentationStep {
        do { try action(); return .returned } catch { return .threw }
    }
}
