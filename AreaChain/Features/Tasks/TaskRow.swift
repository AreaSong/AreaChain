import SwiftUI

struct TaskRow: View {
    var title: String
    var isDone: Bool
    var note: String? = nil
    var todayKey: String? = nil
    var currentDayKey: String? = nil
    var onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var onMoveToDay: ((String) -> Void)? = nil

    @State private var editing = false
    @State private var draft = ""
    @State private var pickingDay = false

    var body: some View {
        HStack(spacing: 8) {
            InkCheckbox(isDone: isDone, action: onToggle)
            if editing {
                editor
            } else {
                titleLabel
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contextMenu { menus }
        .popover(isPresented: $pickingDay) {
            if let todayKey, let onMoveToDay {
                DaySchedulePicker(initialKey: currentDayKey ?? todayKey) { key in
                    onMoveToDay(key)
                    pickingDay = false
                }
            }
        }
        .onAppear { draft = title }
        .onChange(of: title) { _, value in
            if !editing { draft = value }
        }
    }

    private var titleLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13))
                .strikethrough(isDone, color: DaybookTheme.done)
                .foregroundStyle(isDone ? DaybookTheme.done : DaybookTheme.ink)
                .lineLimit(2)
            if let note {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard onEdit != nil else { return }
            draft = title
            editing = true
        }
    }

    private var editor: some View {
        TextField("row.edit.field", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(DaybookTheme.ink)
            .onSubmit(saveEdit)
            .onExitCommand {
                draft = title
                editing = false
            }
    }

    @ViewBuilder
    private var menus: some View {
        if onEdit != nil {
            Button("row.edit") {
                draft = title
                editing = true
            }
        }
        if let todayKey, onMoveToDay != nil {
            DayScheduleMenu(
                todayKey: todayKey,
                currentDayKey: currentDayKey,
                onMove: { onMoveToDay?($0) },
                pickingDay: $pickingDay
            )
        }
        if let onSkip {
            Button("row.skip", action: onSkip)
        }
        if let onDelete {
            Button("row.delete", role: .destructive, action: onDelete)
        }
    }

    private func saveEdit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            onEdit?(next)
        } else {
            draft = title
        }
        editing = false
    }
}
