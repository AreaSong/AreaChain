import SwiftUI

struct TaskRow: View {
    var title: String
    var isDone: Bool
    var isResident: Bool = false
    var note: String? = nil
    var createdAt: Date? = nil
    var remindMinutes: Int? = nil
    var todayKey: String? = nil
    var currentDayKey: String? = nil
    var weekdaysOnly: Bool? = nil
    var onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var onMoveToDay: ((String) -> Void)? = nil
    var onRemindMinutes: ((Int?) -> Void)? = nil
    var onWeekdaysOnly: ((Bool) -> Void)? = nil
    var onDisable: (() -> Void)? = nil
    var onEnable: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @State private var editing = false
    @State private var draft = ""
    @State private var pickingDay = false
    @State private var pickingTime = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            InkCheckbox(isDone: isDone, action: onToggle)
            if isResident {
                residentMark
            }
            if editing {
                editor
            } else {
                titleLabel
            }
            Spacer(minLength: 4)
            actionCluster
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
        .popover(isPresented: $pickingTime) {
            timePicker
        }
        .onAppear { draft = title }
        .onChange(of: title) { _, value in
            if !editing { draft = value }
        }
    }

    private var residentMark: some View {
        Image(systemName: "repeat")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DaybookTheme.stamp)
            .padding(.top, 3)
            .accessibilityLabel("row.resident")
            .help("row.resident")
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
            metaLine
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard onEdit != nil else { return }
            beginEdit()
        }
    }

    @ViewBuilder
    private var metaLine: some View {
        if remindMinutes != nil || createdAt != nil {
            HStack(spacing: 6) {
                if let remindMinutes {
                    Button {
                        pickingTime = true
                    } label: {
                        Text(RemindMinutes.label(remindMinutes, locale: locale))
                    }
                    .buttonStyle(.plain)
                    .disabled(onRemindMinutes == nil)
                }
                if remindMinutes != nil, createdAt != nil {
                    Text("·")
                }
                if let createdAt {
                    Text(ClockLabel.created(createdAt, locale: locale))
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(DaybookTheme.muted)
        }
    }

    private var editor: some View {
        TextField("row.edit.field", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(DaybookTheme.ink)
            .onSubmit(saveEdit)
            .onExitCommand(perform: cancelEdit)
    }

    private var timePicker: some View {
        DatePicker(
            "row.time",
            selection: Binding(
                get: {
                    RemindMinutes.date(minutes: remindMinutes ?? RemindMinutes.from(date: .now)) ?? .now
                },
                set: { onRemindMinutes?(RemindMinutes.from(date: $0)) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .padding(12)
        .frame(minWidth: 180)
    }

    private func beginEdit() {
        draft = title
        editing = true
    }

    private func cancelEdit() {
        draft = title
        editing = false
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

extension TaskRow {
    @ViewBuilder
    private var actionCluster: some View {
        HStack(spacing: 2) {
            if editing {
                RowIconButton(systemName: "checkmark", label: "row.save", action: saveEdit)
                RowIconButton(systemName: "xmark", label: "row.cancel", action: cancelEdit)
            } else {
                if onEdit != nil {
                    RowIconButton(systemName: "pencil", label: "row.edit", action: beginEdit)
                }
                if hasOverflow {
                    Menu {
                        overflowMenus
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DaybookTheme.muted)
                    .menuIndicator(.hidden)
                    .help("row.more")
                    .accessibilityLabel("row.more")
                }
                if let onDelete {
                    RowIconButton(systemName: "trash", label: "row.delete", role: .destructive, action: onDelete)
                }
            }
        }
    }

    private var hasOverflow: Bool {
        onSkip != nil
            || onMoveToDay != nil
            || onRemindMinutes != nil
            || onWeekdaysOnly != nil
            || onDisable != nil
            || onEnable != nil
    }

    @ViewBuilder
    var menus: some View {
        if onEdit != nil {
            Button("row.edit", action: beginEdit)
        }
        overflowMenus
        if let onDelete {
            Button("row.delete", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var overflowMenus: some View {
        timeMenus
        if let todayKey, onMoveToDay != nil {
            DayScheduleMenu(
                todayKey: todayKey,
                currentDayKey: currentDayKey,
                onMove: { onMoveToDay?($0) },
                pickingDay: $pickingDay
            )
        }
        standingMenus
        if let onSkip {
            Button("row.skip", action: onSkip)
        }
    }

    @ViewBuilder
    private var timeMenus: some View {
        if onRemindMinutes != nil {
            Button("row.time.set") {
                if remindMinutes == nil {
                    onRemindMinutes?(RemindMinutes.from(date: .now))
                }
                pickingTime = true
            }
            if remindMinutes != nil {
                Button("row.time.clear") { onRemindMinutes?(nil) }
            }
        }
    }

    @ViewBuilder
    private var standingMenus: some View {
        if let weekdaysOnly, let onWeekdaysOnly {
            Button(weekdaysOnly ? "row.everyday" : "row.weekdays") {
                onWeekdaysOnly(!weekdaysOnly)
            }
        }
        if let onDisable {
            Button("row.disable", action: onDisable)
        }
        if let onEnable {
            Button("row.enable", action: onEnable)
        }
    }
}
