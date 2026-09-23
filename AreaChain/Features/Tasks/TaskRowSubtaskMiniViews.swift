import SwiftUI

struct TaskRowSubtaskChip: View {
    let subtasks: [SubtaskSnapshot]
    @Binding var isExpanded: Bool
    var reduceMotion: Bool = false

    var body: some View {
        let completed = subtasks.filter(\.isDone).count
        let total = subtasks.count
        let allDone = completed == total && total > 0
        return DaybookChip(tint: DaybookPalette.accent.base, isSelected: allDone, action: {
            withAnimation(DaybookMotion.animation(reduceMotion)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                Text("\(completed)/\(total)")
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            }
        }
        .help(isExpanded ? "row.subtasks.collapse" : "row.subtasks.expand")
    }
}

struct TaskRowSubtaskInlineList: View {
    let subtasks: [SubtaskSnapshot]
    var onToggle: ((UUID) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(subtasks) { subtask in
                HStack(spacing: 5) {
                    Button {
                        DaybookHaptics.tap()
                        onToggle?(subtask.id)
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(subtask.isDone ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.4), lineWidth: 1.2) // token-exempt: 40% 次要色没有对应令牌
                                .background(
                                    Circle().fill(subtask.isDone ? DaybookPalette.accent.base : Color.clear)
                                )
                                .frame(width: 12, height: 12)

                            CheckmarkShape()
                                .trim(from: 0, to: subtask.isDone ? 1 : 0)
                                .stroke(
                                    DaybookPalette.checkmark,
                                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                                )
                                .frame(width: 12, height: 12)
                                .animation(DaybookMotion.checkmark(reduceMotion), value: subtask.isDone)
                                .accessibilityHidden(true)
                        }
                        .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain) // control: 复选框，非按钮语义

                    ModernTaskTitle(
                        text: subtask.title,
                        isDone: subtask.isDone,
                        font: .system(size: 11)
                    )
                    .lineLimit(1)
                }
                .padding(.vertical, 0.5)
            }
        }
        .padding(.leading, 2)
        .padding(.top, 2)
    }
}

struct TodoDragIfNeeded: ViewModifier {
    var payload: String?

    func body(content: Content) -> some View {
        if let payload {
            content.draggable(payload)
        } else {
            content
        }
    }
}
