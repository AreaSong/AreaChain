import SwiftData
import SwiftUI

/// 聚焦区常驻页：增改习惯、周期与分类，含停用项。
struct ResidentsPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @State private var draft = ""

    private var items: [DailyRoutine] {
        routines.filter { $0.deletedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tab.residents")
                .font(.system(size: 16, weight: .regular, design: .serif).italic())
                .foregroundStyle(DaybookTheme.ink)
            Text("settings.residents.hint")
                .font(.system(size: 12))
                .foregroundStyle(DaybookTheme.muted)
            addRow
            if items.isEmpty {
                DaybookEmptyState(title: "settings.residents.empty", systemImage: "repeat")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(items, id: \.id) { routine in
                            ResidentEditorRow(routine: routine)
                        }
                    }
                }
                .daybookScroll()
            }
        }
        .daybookPanel(minWidth: 480, minHeight: 480)
    }

    private var addRow: some View {
        HStack {
            TextField("resident.add", text: $draft)
                .textFieldStyle(.plain)
                .onSubmit(add)
            ComposerAddButton(
                enabled: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: add
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookTheme.hoverFill.opacity(0.75))
        )
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        DayBoardMutations.persist {
            modelContext.insert(DailyRoutine(title: title, sortOrder: order))
            draft = ""
        }
    }
}

private struct ResidentEditorRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var checks: [RoutineCheck]
    var routine: DailyRoutine

    @State private var titleDraft = ""
    @State private var pickingTime = false
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            scheduleRow
            ClassifyBitsEditor(
                bits: routine.classifyBits,
                projects: CatalogChoices.projects(projects),
                tags: CatalogChoices.tags(tags, attachedIDs: routine.tagIDs),
                onProject: { id in persist { routine.projectID = id } },
                onToggleTag: { id in persist { routine.tagIDs = TagIDList.toggling(routine.tagIDs, id) } },
                onImportant: { value in persist { routine.isImportant = value } },
                onUrgent: { value in persist { routine.isUrgent = value } }
            )
        }
        .padding(10)
        .modernCard(cornerRadius: DaybookRadius.small)
        .onAppear { titleDraft = routine.title }
        .onChange(of: routine.title) { _, value in
            if titleDraft != value { titleDraft = value }
        }
        .popover(isPresented: $pickingTime) {
            DatePicker("row.time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .padding(12)
                .frame(minWidth: 180)
        }
        .confirmMoveToTrash($pendingTrash)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            TextField("settings.residents.rename", text: $titleDraft)
                .textFieldStyle(.plain)
                .onSubmit(saveTitle)
            Toggle("settings.residents.enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .help("settings.residents.enabled")
            RowIconButton(systemName: "trash", label: "row.delete", role: .destructive, action: requestTrash)
        }
    }

    private var scheduleRow: some View {
        HStack(spacing: 8) {
            WeekdayMaskChips(mask: routine.resolvedWeekdayMask, onToggle: toggleWeekday)
            Spacer(minLength: 8)
            timeControls
        }
        .font(.system(size: 12))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { routine.isEnabled },
            set: { next in
                DayBoardMutations.setRoutineEnabled(
                    routine,
                    enabled: next,
                    todayKey: DayClock.shared.todayKey,
                    checks: checks,
                    context: modelContext
                )
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                RemindMinutes.date(minutes: routine.remindMinutes ?? RemindMinutes.from(date: .now)) ?? .now
            },
            set: { date in setRemind(RemindMinutes.from(date: date)) }
        )
    }

    @ViewBuilder
    private var timeControls: some View {
        Button("row.time.set") {
            if routine.remindMinutes == nil {
                setRemind(RemindMinutes.from(date: .now))
            }
            pickingTime = true
        }
        .buttonStyle(.plain)
        .foregroundStyle(DaybookTheme.muted)
        if let minutes = routine.remindMinutes {
            Text(RemindMinutes.label(minutes, locale: locale))
                .foregroundStyle(DaybookTheme.muted)
                .monospacedDigit()
            Button("row.time.clear") { setRemind(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(DaybookTheme.muted)
        }
    }

    private func saveTitle() {
        let next = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.isEmpty {
            titleDraft = routine.title
            return
        }
        persist {
            routine.title = next
            titleDraft = next
        }
    }

    private func requestTrash() {
        pendingTrash = PendingTrash(title: routine.title) {
            DayBoardMutations.trashRoutine(routine)
        }
    }

    private func setRemind(_ minutes: Int?) {
        persist { routine.remindMinutes = RemindMinutes.clamped(minutes) }
        DayBoardMutations.requestReminderAccessIfNeeded(minutes)
    }

    private func toggleWeekday(_ weekday: Int) {
        persist {
            routine.setWeekdayMask(WeekdayMask.toggling(routine.resolvedWeekdayMask, weekday: weekday))
        }
    }

    private func persist(_ work: () -> Void) {
        DayBoardMutations.persist(work)
    }
}

private struct WeekdayMaskChips: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    var mask: Int
    var onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                let on = WeekdayMask.contains(mask, weekday: weekday)
                Button {
                    onToggle(weekday)
                } label: {
                    Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(on ? DaybookTheme.stamp.opacity(0.38) : DaybookTheme.rule.opacity(0.45))
                        .foregroundStyle(on ? DaybookTheme.ink : DaybookTheme.muted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
                .accessibilityAddTraits(on ? [.isSelected] : [])
                .help(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("settings.residents.days")
        .help("settings.residents.days")
    }
}
