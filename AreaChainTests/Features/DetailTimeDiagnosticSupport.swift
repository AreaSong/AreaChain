import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 非 Observable 记录器不发布状态；仅诊断宿主使用原 body 的只读展开。
@MainActor
final class DetailTimeTrace {
    var events: [String] = []
    var reads: [String] = []

    func record(_ phase: String, fixture: TimePickerConsumerFixture, due: Bool, window: NSWindow) throws {
        let nodes = try DetailTimeSupport.nodes(due: due, in: window)
        let labels = Set(nodes.flatMap { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].compactMap {
                SettingsButtonTestSupport.value(node, $0) as? String
            }
        }).sorted()
        let clears = try DetailTimeSupport.buttons("row.time.clear", due: due, in: window).count
        events.append("\(phase) window=\(ObjectIdentifier(window)) view=\(String(describing: window.contentView.map(ObjectIdentifier.init))) "
            + "todo=\(ObjectIdentifier(fixture.todo)) remind=\(String(describing: fixture.todo.remindMinutes)) "
            + "due=\(String(describing: fixture.todo.dueMinutes)) routine=\(String(describing: fixture.routine.remindMinutes)) "
            + "clears=\(clears) labels=\(labels)")
    }

    func inspect(_ value: Any, depth: Int = 0) {
        guard depth < 8 else { return }
        if let chips = value as? TaskDetailRemindChips {
            reads.append("parent body -> remind=\(String(describing: chips.remindMinutes))")
            return
        }
        if let due = value as? TaskDetailDueTime {
            reads.append("parent body -> due=\(String(describing: due.dueMinutes))")
            return
        }
        for child in Mirror(reflecting: value).children { inspect(child.value, depth: depth + 1) }
    }

    func emit(_ name: String) {
        print("TIME_CLEAR_10H \(name)\n" + (events + reads).joined(separator: "\n"))
    }
}

/// 与正常验收分开：把原父 body 的读取范围留在此探针，不添加镜像值或刷新依赖。
private struct DetailTimeReadProbe: View {
    let fixture: TimePickerConsumerFixture
    let trace: DetailTimeTrace

    var body: some View {
        let content = TodoScheduleSectionView(todo: fixture.todo).body
        trace.inspect(content)
        return content
    }
}

@MainActor
enum DetailTimeDiagnosticSupport {
    static func window(_ fixture: TimePickerConsumerFixture, trace: DetailTimeTrace) -> NSWindow {
        fixture.native.window(DetailTimeReadProbe(fixture: fixture, trace: trace).padding(12),
                              size: NSSize(width: 320, height: 540))
    }
}
