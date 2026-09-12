import SwiftUI

extension DayBoardList {
    @ViewBuilder
    var openItemsSection: some View {
        if !openTodosList.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionStamp(title: "stamp.todos", icon: "checklist", count: openTodosList.count)
                ForEach(openTodosList) { todo in
                    todoRow(todo, isDone: false)
                }
            }
        }
        if !openRoutinesList.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionStamp(title: "stamp.routines", icon: "repeat", count: openRoutinesList.count)
                ForEach(openRoutinesList) { routine in
                    residentRow(routine, isDone: false)
                }
            }
        }
        if openTodosList.isEmpty && openRoutinesList.isEmpty && !doneItemsList.isEmpty {
            allDoneBanner
        }
    }

    var allDoneBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(DaybookType.title)
                .foregroundStyle(DaybookTheme.stamp)
            Text("太棒了，今日任务全清！")
                .font(DaybookType.body.weight(.medium))
                .foregroundStyle(DaybookTheme.ink)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .fill(DaybookTheme.stamp.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .stroke(DaybookTheme.stamp.opacity(0.15), lineWidth: 1)
        )
        .padding(.top, 4)
    }

    var completedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .opacity(0.15)
                .padding(.top, 4)
                .padding(.bottom, 4)

            Button {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                    SectionStamp(
                        title: showCompleted
                            ? "stamp.completed.collapse \(doneItemsList.count)"
                            : "stamp.completed \(doneItemsList.count)",
                        icon: "checkmark.circle"
                    )
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showCompleted ? 1.0 : 0.6)
            .accessibilityAddTraits(showCompleted ? [.isSelected] : [])

            if showCompleted {
                ForEach(doneItemsList) { row in
                    dayRow(row, isDone: true)
                }
            }
        }
    }
}

struct DayBoardKeyNavigationModifier: ViewModifier {
    var interaction: DayBoardInteraction
    var onNavigate: (Int) -> Void
    var onToggle: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onInspect: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) { handle(.downArrow) }
            .onKeyPress(.upArrow) { handle(.upArrow) }
            .onKeyPress(.space) { handle(.space) }
            .onKeyPress(.delete) { handle(.delete) }
            .onKeyPress(.return) { handle(.return) }
    }

    func handle(_ key: KeyEquivalent) -> KeyPress.Result {
        guard interaction.isKeyboardEnabled(), let focus = interaction.focusedTaskID else { return .ignored }
        switch key {
        case .downArrow: onNavigate(1)
        case .upArrow: onNavigate(-1)
        case .space:
            guard let id = focus.wrappedValue else { return .ignored }
            onToggle(id)
        case .delete:
            guard let id = focus.wrappedValue else { return .ignored }
            onDelete(id)
        case .return:
            guard let id = focus.wrappedValue else { return .ignored }
            onInspect(id)
        default: return .ignored
        }
        return .handled
    }
}
