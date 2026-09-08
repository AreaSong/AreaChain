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
        .buttonStyle(.plain)
        .help(isExpanded ? "收起子任务" : "展开子任务")
    }
}

struct TaskRowSubtaskInlineList: View {
    let subtasks: [SubtaskSnapshot]
    var onToggle: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(subtasks) { subtask in
                HStack(spacing: 5) {
                    Button {
                        onToggle?(subtask.id)
                    } label: {
                        Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 10))
                            .foregroundStyle(subtask.isDone ? DaybookTheme.stamp : DaybookTheme.muted)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(.system(size: 11))
                        .foregroundStyle(subtask.isDone ? DaybookTheme.muted.opacity(0.6) : DaybookTheme.ink)
                        .strikethrough(subtask.isDone, color: DaybookTheme.muted.opacity(0.5))
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
