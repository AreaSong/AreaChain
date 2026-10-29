import Foundation
import SwiftData
@testable import AreaChain

/// 适配器改为自读备注、取带键摘要。夹具原来靠“来源所有者声明”切换备注资格，
/// 现在在来源回调里落成真实状态：present 写入并保存合成备注，absent 清掉合成备注，unknown 撤走协调者密钥（无法证明）。
/// 来源回调总在适配读备注之前、事务之外调用，因此在这里写库不会落进被测事务。
enum SyntheticNotes: Equatable {
    case absent, present, unknown
    static let text = "合成备注"
}

@MainActor final class SyntheticNotesSwitch {
    var state = SyntheticNotes.absent
    private var parked: CommandTextDigest?

    func apply<Environment: AnyObject>(to target: CommandObjectReference, in context: ModelContext, environment: Environment?,
                                       key: ReferenceWritableKeyPath<Environment, CommandTextDigest?>) throws {
        if let environment {
            if state == .unknown {
                if let current = environment[keyPath: key] { parked = current }
                environment[keyPath: key] = nil
            } else if environment[keyPath: key] == nil, let parked {
                environment[keyPath: key] = parked
                self.parked = nil
            }
        }
        guard state != .unknown else { return }
        try write(state == .present ? SyntheticNotes.text : nil, to: target, in: context)
    }

    /// absent 只清掉本夹具写入的合成备注，不覆盖测试自己写的备注。
    private func write(_ text: String?, to target: CommandObjectReference, in context: ModelContext) throws {
        let id = target.id
        switch target.type {
        case .todo:
            let rows = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
            guard rows.count == 1 else { return }
            try update(current: rows[0].notes, text: text, in: context) { rows[0].notes = $0 }
        case .routine:
            let rows = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
            guard rows.count == 1 else { return }
            try update(current: rows[0].notes, text: text, in: context) { rows[0].notes = $0 }
        default: return
        }
    }

    private func update(current: String, text: String?, in context: ModelContext, set: (String) -> Void) throws {
        if let text, current != text { set(text) } else if text == nil, current == SyntheticNotes.text { set("") } else { return }
        try context.save()
    }
}
