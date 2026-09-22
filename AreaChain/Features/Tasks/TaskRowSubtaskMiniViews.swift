import SwiftUI

struct TaskRowSubtaskChip: View {
    let subtasks: [SubtaskSnapshot]
    @Binding var isExpanded: Bool
    var reduceMotion: Bool = false

    var body: some View {
        let completed = subtasks.filter(\.isDone).count
        let total = subtasks.count
        let allDone = completed == total && total > 0

        Button {
            withAnimation(DaybookMotion.animation(reduceMotion)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 8))
                Text("\(completed)/\(total)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 6))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(allDone ? DaybookTheme.stamp.opacity(0.15) : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .stroke(allDone ? DaybookTheme.stamp.opacity(0.4) : DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                    )
            )
            .foregroundStyle(allDone ? DaybookTheme.stamp : DaybookTheme.muted)
        }
        .buttonStyle(.plain) // control: 子任务计数芯片，P5 迁 DaybookChip(.count)
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
                                .strokeBorder(subtask.isDone ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.4), lineWidth: 1.2)
                                .background(
                                    Circle().fill(subtask.isDone ? DaybookTheme.stamp : Color.clear)
                                )
                                .frame(width: 12, height: 12)

                            CheckmarkShape()
                                .trim(from: 0, to: subtask.isDone ? 1 : 0)
                                .stroke(
                                    DaybookTheme.checkmark,
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
