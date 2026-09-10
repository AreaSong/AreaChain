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
    @State private var dayTick = Date()
    @State private var draftText = ""
    @FocusState private var composerFocused: Bool

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var openTodosCount: Int {
        todos.filter { $0.dayKey == todayKey && $0.deletedAt == nil && !$0.isDone }.count
    }

    private var completedTodosCount: Int {
        todos.filter { $0.dayKey == todayKey && $0.deletedAt == nil && $0.isDone }.count
    }

    private var totalTodosCount: Int {
        openTodosCount + completedTodosCount
    }

    private var progressRatio: Double {
        guard totalTodosCount > 0 else { return completedTodosCount > 0 ? 1.0 : 0.0 }
        return Double(completedTodosCount) / Double(totalTodosCount)
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
                text: $draftText,
                placeholder: L10n.string("workspace.composer.placeholder", locale: locale),
                focus: $composerFocused,
                availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
                onSubmit: addTodo,
                onCommandReturn: {}
            ) {
                CaptureTokenBar(text: draftText)
            }

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
                    )
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private var headerTrailing: some View {
        HStack(spacing: 10) {
            Button {
                navigation.revealTab(.residents)
            } label: {
                Label("tab.residents", systemImage: "repeat")
                    .font(DaybookType.caption)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            .help("workspace.residents.open")

            if totalTodosCount > 0 {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(completedTodosCount >= totalTodosCount ? "workspace.progress.done" : "workspace.progress.label")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookTheme.muted)

                        Text("\(completedTodosCount)/\(totalTodosCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(completedTodosCount >= totalTodosCount ? DaybookTheme.stamp : DaybookTheme.ink)
                    }

                    DaybookProgressRing(progress: progressRatio, lineWidth: 3.5, size: 36)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                        .fill(DaybookTheme.hoverFill)
                )
            }
        }
    }

    private func addTodo() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let todo = TodoItem(
            title: parsed.cleanTitle,
            dayKey: todayKey,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.isImportant,
            isUrgent: parsed.isUrgent,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp),
            notes: parsed.notes
        )
        if let tagName = parsed.tagName,
           let tag = DayBoardMutations.resolveTaskTag(named: tagName, among: tags, context: modelContext)
        {
            todo.tagIDs = TagIDList.toggling(todo.tagIDs, tag.id)
        }
        modelContext.insert(todo)
        draftText = ""
        BoardEvents.changed()
        DayBoardMutations.requestReminderAccessIfNeeded(parsed.remindMinutes)
    }
}
