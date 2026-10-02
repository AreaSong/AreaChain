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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(subtasks) { subtask in
                HStack(spacing: 5) {
                    ModernCheckbox(isDone: subtask.isDone, presentation: .inlineSubtask) {
                        onToggle?(subtask.id)
                    }
                    .accessibilityIdentifier("task.subtask.complete.\(subtask.id)")

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
