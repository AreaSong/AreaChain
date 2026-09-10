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
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.stamp)
            Text("header.done")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var completedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
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
    var focusedTaskID: Binding<UUID?>?
    var onNavigate: (Int) -> Void
    var onToggle: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onInspect: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) {
                guard focusedTaskID != nil else { return .ignored }
                onNavigate(1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard focusedTaskID != nil else { return .ignored }
                onNavigate(-1)
                return .handled
            }
            .onKeyPress(.space) {
                if let id = focusedTaskID?.wrappedValue {
                    onToggle(id)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if let id = focusedTaskID?.wrappedValue {
                    onDelete(id)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.return) {
                if let id = focusedTaskID?.wrappedValue {
                    onInspect(id)
                    return .handled
                }
                return .ignored
            }
    }
}
