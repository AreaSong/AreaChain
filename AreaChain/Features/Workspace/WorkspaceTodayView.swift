import SwiftData
import SwiftUI

struct WorkspaceTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    private var dayClock: DayClock { DayClock.shared }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @Bindable private var filterSession = BoardFilterSession.shared
    @State private var dayTick = Date()
    @State private var composerFocused = false
    @State private var showingRecurringEditor = false
    @State private var showingRecurringList = false

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    var body: some View {
        DaybookPage(
            title: "workspace.today.title",
            subtitleText: DayKey.displayName(todayKey, locale: locale),
            minWidth: 480,
            minHeight: 480
        ) {
            headerTrailing
        } content: {
            DaybookComposer(
                text: $navigation.todayDraft,
                placeholder: L10n.string("workspace.composer.placeholder", locale: locale),
                focus: $composerFocused,
                availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
                onSubmit: addTodo,
                onCommandReturn: {}
            )

            TasksPage(
                todayKey: todayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                config: TasksPageConfig(
                    yesterdayKey: dayClock.yesterdayKey,
                    interaction: DayBoardInteraction(
                        focusedTaskID: $navigation.selectedTaskID,
                        highlightedTaskID: navigation.selectedTaskID,
                        onInspect: { WorkspaceNavigation.shared.inspectTask($0) },
                        onReturnToInput: {
                            navigation.selectedTaskID = nil
                            composerFocused = true
                        }
                    ),
                    // 写入共享筛选会话；工作台过滤条是否出现不再取决于这个 binding 是否存在。
                    externalFilter: Binding(
                        get: { filterSession.filters.tasks },
                        set: { writeTaskFilter($0) }
                    )
                )
            )
        }
        .onAppear {
            consumeComposerFocus()
            consumeRecurringListRequest()
        }
        .onChange(of: navigation.wantsTodayComposerFocus) { _, _ in
            consumeComposerFocus()
        }
        .onChange(of: navigation.wantsRecurringList) { _, _ in
            consumeRecurringListRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
        .sheet(isPresented: $showingRecurringEditor) {
            // macOS 的 sheet 不继承外层 locale，不补上就按系统语言显示。
            RecurringItemEditor()
                .environment(\.locale, locale)
                .frame(minWidth: 460, minHeight: 520)
        }
        .sheet(isPresented: $showingRecurringList) {
            ResidentsPage()
                .environment(\.locale, locale)
                .frame(minWidth: 560, minHeight: 480)
        }
    }

    @ViewBuilder
    private var headerTrailing: some View {
        let progress = todayProgress
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                recurringHeaderButton(systemName: "plus", key: "recurring.create.open") {
                    showingRecurringEditor = true
                }
                recurringHeaderButton(systemName: "repeat", key: "workspace.residents.open") {
                    showingRecurringList = true
                }
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(progressTitleKey(progress))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)

                Text("\(progress.completed)/\(progress.total)")
                    .font(DaybookType.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(progressColor(progress))
            }

            DaybookProgressRing(progress: progress.ratio, lineWidth: 3.5, size: 36)
        }
        .animation(DaybookMotion.interactive, value: progress.total)
        .animation(DaybookMotion.interactive, value: progress.completed)
    }

    private func recurringHeaderButton(systemName: String, key: String, action: @escaping () -> Void) -> some View {
        let title = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        return Button(action: action) {
            Label {
                Text(verbatim: title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: systemName)
            }
            .font(DaybookType.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
        .accessibilityLabel(Text(verbatim: title))
        .help(Text(verbatim: title))
    }

    private var todayProgress: BoardProgress {
        DayBoardLogic.todayProgress(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
    }

    private func progressColor(_ progress: BoardProgress) -> Color {
        let finished = progress.total > 0 && progress.completed >= progress.total
        return finished ? DaybookPalette.accent.base : DaybookPalette.text.primary
    }

    private func progressTitleKey(_ progress: BoardProgress) -> LocalizedStringKey {
        if progress.total == 0 {
            return "workspace.progress.label"
        }
        return progress.completed >= progress.total ? "workspace.progress.done" : "workspace.progress.label"
    }

    private func consumeComposerFocus() {
        guard navigation.wantsTodayComposerFocus else { return }
        navigation.wantsTodayComposerFocus = false
        composerFocused = true
    }

    private func consumeRecurringListRequest() {
        guard navigation.wantsRecurringList else { return }
        navigation.wantsRecurringList = false
        showingRecurringList = true
    }

    private func writeTaskFilter(_ filter: BoardFilter) {
        var next = filterSession.filters
        next.write(filter, for: .tasks)
        filterSession.filters = next
    }

    private func addTodo() {
        let saved = DayBoardMutations.addCapturedTodo(
            text: navigation.todayDraft, dayKey: todayKey, context: modelContext
        )
        guard saved else { return }
        navigation.todayDraft = ""
    }
}
