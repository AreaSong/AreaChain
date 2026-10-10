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

    @WorkspaceNavigationContext private var navigation
    @WorkspaceFilterContext private var filterSession
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
                        onInspect: { navigation.inspectTask($0) },
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
        .workspaceHeader(actions: headerActions, status: AnyView(headerTrailing))
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
                .environment(\.workspaceEmbedded, false)
                .frame(minWidth: 460, minHeight: 520)
        }
        .sheet(isPresented: $showingRecurringList) {
            ResidentsPage()
                .environment(\.locale, locale)
                .environment(\.workspaceEmbedded, false)
                .frame(minWidth: 560, minHeight: 480)
        }
    }

    private var headerActions: [WorkspaceHeaderAction] {
        [WorkspaceHeaderAction(id: "recurring", title: "workspace.recurring.menu", systemImage: "repeat", children: [
            WorkspaceHeaderAction(id: "recurring.create", title: "recurring.create.open", systemImage: "plus") {
                showingRecurringEditor = true
            },
            WorkspaceHeaderAction(id: "recurring.manage", title: "workspace.residents.open", systemImage: "repeat") {
                showingRecurringList = true
            }
        ])]
    }

    private var headerTrailing: some View {
        let progress = todayProgress
        return HStack(spacing: DaybookSpacing.xs) {
            DaybookProgressRing(progress: progress.ratio, lineWidth: 2, size: DaybookMetrics.Hit.inline, showsPercentage: false)
            Text("\(progress.completed)/\(progress.total)")
                .font(DaybookType.caption.monospacedDigit())
                .foregroundStyle(progressColor(progress))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("workspace.progress.count \(progress.completed) \(progress.total)"))
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
