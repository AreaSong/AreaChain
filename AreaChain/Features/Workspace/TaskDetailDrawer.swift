import SwiftData
import SwiftUI

/// 任务检查器抽屉：待办与习惯共用分区。
struct TaskDetailDrawer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var taskID: UUID?

    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Query private var checks: [RoutineCheck]

    @Bindable private var boardSelection = BoardSelection.shared
    @State private var previewAttachment: AttachmentRef?
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        Group {
            if let taskID, let todo = todos.first(where: { $0.id == taskID && $0.deletedAt == nil }) {
                todoDetailView(todo)
            } else if let taskID, let routine = routines.first(where: { $0.id == taskID && $0.deletedAt == nil }) {
                routineDetailView(routine)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                DaybookTheme.paper.opacity(0.4)
            }
        }
        .confirmMoveToTrash($pendingTrash)
        .popover(item: $previewAttachment) { item in
            attachmentPreviewSheet(item)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DaybookTheme.muted.opacity(0.5))
            Text("drawer.empty.title")
                .font(DaybookType.body.weight(.medium))
                .foregroundStyle(DaybookTheme.muted)
            Text("drawer.empty.hint")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Todo Detail View

    // MARK: - Todo Detail View

    private func todoDetailView(_ todo: TodoItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                todoHeader(todo)
                TodoBasicsSectionView(todo: todo)
                TodoScheduleSectionView(todo: todo)
                TodoClassificationSectionView(todo: todo, projects: projects, tags: tags, modelContext: modelContext)
                TaskDetailAssetsSectionView(
                    props: TaskDetailAssetsProps(ownerID: todo.id, ownerKind: .todo, createdAt: todo.createdAt, sourceBundleID: todo.sourceBundleID),
                    attachments: attachments,
                    modelContext: modelContext,
                    onPreview: { previewAttachment = $0 }
                )
            }
            .padding(16)
        }
        .daybookScroll()
    }

    private func todoHeader(_ todo: TodoItem) -> some View {
        TaskDetailHeaderBar(
            isDone: todo.isDone,
            onToggle: { DayBoardMutations.toggleTodo(todo) },
            onTrash: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                    taskID = nil
                    WorkspaceNavigation.shared.closeInspector()
                }
            },
            onClose: {
                WorkspaceNavigation.shared.closeInspector()
            }
        )
    }

    // MARK: - Routine Detail View

    private func routineDetailView(_ routine: DailyRoutine) -> some View {
        let boardDayKey = boardSelection.inspectingDayKey
        let todayKey = DayClock.shared.todayKey
        let streakResult = HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: todayKey
        )
        let isDoneOnBoard = checks.contains {
            $0.routine?.id == routine.id
                && $0.dayKey == boardDayKey
                && $0.isDone
                && $0.isSkipped != true
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                routineHeader(routine, isDoneOnBoard: isDoneOnBoard, boardDayKey: boardDayKey)
                RoutineHabitSectionView(
                    routine: routine,
                    streakResult: streakResult,
                    boardDayKey: boardDayKey,
                    isDoneOnBoard: isDoneOnBoard,
                    isSkipped: checks.contains {
                        $0.routine?.id == routine.id && $0.dayKey == boardDayKey && $0.isSkipped
                    }
                )
                RoutineScheduleSectionView(routine: routine)
                RoutineClassificationSectionView(routine: routine, projects: projects, tags: tags, modelContext: modelContext)
                TaskDetailAssetsSectionView(
                    props: TaskDetailAssetsProps(ownerID: routine.id, ownerKind: .routine, createdAt: routine.createdAt, sourceBundleID: routine.sourceBundleID),
                    attachments: attachments,
                    modelContext: modelContext,
                    onPreview: { previewAttachment = $0 }
                )
            }
            .padding(16)
        }
        .daybookScroll()
    }

    private func routineHeader(_ routine: DailyRoutine, isDoneOnBoard: Bool, boardDayKey: String) -> some View {
        TaskDetailHeaderBar(
            isDone: isDoneOnBoard,
            isRoutine: true,
            onToggle: {
                DayBoardMutations.toggleRoutine(
                    routine,
                    on: boardDayKey,
                    checks: checks,
                    context: modelContext
                )
            },
            onTrash: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                    taskID = nil
                    WorkspaceNavigation.shared.closeInspector()
                }
            },
            onClose: {
                WorkspaceNavigation.shared.closeInspector()
            }
        )
    }

    private func attachmentPreviewSheet(_ item: AttachmentRef) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DaybookTheme.ink)
                Spacer()
                Button("common.close") {
                    previewAttachment = nil
                }
                .buttonStyle(.plain)
            }

            if let image = AttachmentStore.image(id: item.id) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400)
            }
        }
        .padding(12)
        .frame(minWidth: 280, minHeight: 200)
    }
}

// MARK: - Drawer Section Group

struct DrawerSectionGroup<Content: View>: View {
    var title: LocalizedStringKey? = nil
    var content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.leading, 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .fill(DaybookTheme.cardSurface.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
            )
        }
    }
}

