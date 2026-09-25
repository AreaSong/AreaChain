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
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Query private var checks: [RoutineCheck]

    @Bindable private var boardSelection = BoardSelection.shared
    @State private var previewAttachment: AttachmentRef?
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        Group {
            if let taskID, let reference = WorkspaceNavigation.shared.inspectedReference, reference.modelID == taskID {
                switch reference {
                case .todo:
                    if let todo = todos.first(where: { $0.id == taskID && $0.deletedAt == nil }) {
                        todoDetailView(todo)
                    } else {
                        emptyState
                    }
                case .recurring:
                    if let routine = routines.first(where: { $0.id == taskID && $0.deletedAt == nil }) {
                        routineDetailView(routine)
                    } else {
                        emptyState
                    }
                }
            } else if let taskID, let todo = todos.first(where: { $0.id == taskID && $0.deletedAt == nil }) {
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
                DaybookPalette.fill.page.opacity(0.4) // token-exempt: 40% 纸色没有对应令牌
            }
        }
        .syntaxOverlayHost()
        .confirmMoveToTrash($pendingTrash)
        .popover(item: $previewAttachment) { item in
            attachmentPreviewSheet(item)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 36, weight: .light)) // token-exempt: display 是 26pt，这处是 36pt light
                .foregroundStyle(DaybookPalette.text.secondary.opacity(0.5)) // token-exempt: 50% 次要色没有对应令牌
            Text("drawer.empty.title")
                .font(DaybookType.body.weight(.medium))
                .foregroundStyle(DaybookPalette.text.secondary)
            Text("drawer.empty.hint")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
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
                TodoClassificationSectionView(todo: todo, tags: tags, modelContext: modelContext)
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
        let allowsCompletion = WorkspaceNavigation.shared.allowsRoutineCompletion(routine.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                routineHeader(
                    routine,
                    isDoneOnBoard: isDoneOnBoard,
                    boardDayKey: boardDayKey,
                    allowsCompletion: allowsCompletion
                )
                RoutineHabitSectionView(
                    routine: routine,
                    streakResult: streakResult,
                    boardDayKey: boardDayKey,
                    isDoneOnBoard: isDoneOnBoard,
                    isSkipped: checks.contains {
                        $0.routine?.id == routine.id && $0.dayKey == boardDayKey && $0.isSkipped
                    },
                    onSkip: allowsCompletion ? {
                        DayBoardMutations.skipRoutine(
                            routine,
                            on: boardDayKey,
                            checks: checks,
                            context: modelContext
                        )
                    } : nil
                )
                RoutineScheduleSectionView(routine: routine)
                RoutineClassificationSectionView(routine: routine, tags: tags, modelContext: modelContext)
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

    private func routineHeader(
        _ routine: DailyRoutine,
        isDoneOnBoard: Bool,
        boardDayKey: String,
        allowsCompletion: Bool
    ) -> some View {
        TaskDetailHeaderBar(
            isDone: isDoneOnBoard,
            isRoutine: true,
            showsCompletion: allowsCompletion,
            onToggle: {
                guard allowsCompletion else { return }
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
                    .font(DaybookType.subtitle.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                Button("common.close") {
                    previewAttachment = nil
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
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
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .tracking(0.5)
                    .padding(.leading, 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .daybookSurface(.card)
        }
    }
}
