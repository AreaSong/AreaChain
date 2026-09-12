import SwiftData
import SwiftUI

/// 聚焦区常驻页：增改习惯、周期与排序；详情走检查器。
struct ResidentsPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @State private var draft = ""

    private var items: [DailyRoutine] {
        routines.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        DaybookPage(title: "tab.residents", subtitle: "residents.hint") {
            DaybookComposer(text: $draft, placeholder: "resident.add", onSubmit: add)
            if items.isEmpty {
                DaybookEmptyState(title: "residents.empty", systemImage: "repeat")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    ForEach(items, id: \.id) { routine in
                        ResidentEditorRow(routine: routine)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = Catalog.nextSortOrder(routines.map(\.sortOrder))
        if DayBoardMutations.persist(context: modelContext, {
            modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        }) {
            draft = ""
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        DayBoardMutations.reorderRoutines(items, from: source, to: destination)
    }
}

private struct ResidentEditorRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Bindable private var navigation = WorkspaceNavigation.shared
    @Query private var checks: [RoutineCheck]
    var routine: DailyRoutine

    @State private var titleDraft = ""
    @State private var pickingTime = false
    @State private var pendingTrash: PendingTrash?

    private var isSelected: Bool {
        navigation.selectedTaskID == routine.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            scheduleRow
        }
        .padding(10)
        .modernCard(cornerRadius: DaybookRadius.small, isSelected: isSelected)
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
            TextField("residents.rename", text: $titleDraft)
                .textFieldStyle(.plain)
                .onSubmit(saveTitle)
            Toggle("residents.enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .help("residents.enabled")
            Button {
                navigation.inspectTask(routine.id)
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                    .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
            }
            .buttonStyle(.plain)
            .help("drawer.inspector.toggle")
            RowIconButton(systemName: "trash", label: "row.delete", role: .destructive, action: requestTrash)
        }
    }

    private var scheduleRow: some View {
        HStack(spacing: 8) {
            WeekdayMaskChips(mask: routine.resolvedWeekdayMask, onToggle: toggleWeekday)
            Spacer(minLength: 8)
            timeControls
        }
        .font(DaybookType.subtitle)
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
        DayBoardMutations.persist(context: modelContext) {
            routine.title = next
            titleDraft = next
        }
    }

    private func requestTrash() {
        pendingTrash = PendingTrash(title: routine.title) {
            DayBoardMutations.trashRoutine(routine)
            if navigation.selectedTaskID == routine.id {
                navigation.selectedTaskID = nil
                navigation.closeInspector()
            }
        }
    }

    private func setRemind(_ minutes: Int?) {
        DayBoardMutations.setRemind(routine, minutes: minutes)
    }

    private func toggleWeekday(_ weekday: Int) {
        DayBoardMutations.persist(context: modelContext) {
            routine.setWeekdayMask(WeekdayMask.toggling(routine.resolvedWeekdayMask, weekday: weekday))
        }
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
                        .font(DaybookType.caption.weight(.semibold))
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
        .accessibilityLabel("residents.days")
        .help("residents.days")
    }
}
