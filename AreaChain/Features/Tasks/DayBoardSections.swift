import SwiftUI

extension DayBoardList {
    @ViewBuilder
    var openItemsSection: some View {
        if !openTodosList.isEmpty {
            if !openRoutinesList.isEmpty {
                SectionStamp(title: "stamp.todos", icon: "checklist", count: openTodosList.count)
                    .padding(.leading, 2)
            }
            DaybookGroupedCard {
                ForEach(Array(openTodosList.enumerated()), id: \.element.id) { index, todo in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 36)
                            .opacity(0.35)
                    }
                    todoRow(todo, isDone: false)
                }
            }
        }
        if !openRoutinesList.isEmpty {
            SectionStamp(title: "stamp.routines", icon: "repeat", count: openRoutinesList.count)
                .padding(.leading, 2)
            DaybookGroupedCard {
                ForEach(Array(openRoutinesList.enumerated()), id: \.element.id) { index, routine in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 36)
                            .opacity(0.35)
                    }
                    residentRow(routine, isDone: false)
                }
            }
        }
        if openTodosList.isEmpty && openRoutinesList.isEmpty && !doneItemsList.isEmpty {
            allDoneBanner
        }
    }

    var allDoneBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.stamp)
            Text("太棒了，今日任务全清！")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookTheme.ink.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookTheme.stamp.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookTheme.stamp.opacity(0.12), lineWidth: 0.8)
        )
        .padding(.top, 2)
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
            .buttonStyle(.plain) // control: 分节折叠头，整行点击
            .opacity(showCompleted ? 1.0 : 0.6)
            .accessibilityAddTraits(showCompleted ? [.isSelected] : [])

            if showCompleted {
                DaybookGroupedCard {
                    ForEach(Array(doneItemsList.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 36)
                                .opacity(0.3)
                        }
                        dayRow(row, isDone: true)
                    }
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
