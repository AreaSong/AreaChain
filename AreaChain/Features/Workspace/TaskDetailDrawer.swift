import SwiftData
import SwiftUI

/// 现代 Pro 风格任务检查器抽屉容器：组织子组件，支持待办与习惯双形态
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
            Text("drawer.empty.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Todo Detail View

    private func todoDetailView(_ todo: TodoItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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

                DrawerSectionGroup(title: "drawer.section.basics") {
                    TaskDetailTitleEditor(title: todo.title) { newTitle in
                        DayBoardMutations.editTodo(todo, title: newTitle)
                    }

                    TaskDetailNotesView(notes: todo.notes) { newNotes in
                        DayBoardMutations.updateNotes(for: todo, notes: newNotes)
                    }
                    .id(todo.id)

                    TaskDetailSubtasksView(todo: todo)
                }

                DrawerSectionGroup(title: "drawer.section.schedule") {
                    TaskDetailQuadrantGrid(
                        isImportant: todo.isImportant,
                        isUrgent: todo.isUrgent,
                        onSelect: { imp, urg in
                            DayBoardMutations.persist {
                                todo.isImportant = imp
                                todo.isUrgent = urg
                            }
                        }
                    )

                    TaskDetailRemindChips(remindMinutes: todo.remindMinutes) { minutes in
                        DayBoardMutations.setRemind(todo, minutes: minutes)
                    }

                    TaskDetailDateChips(dayKey: todo.dayKey) { newDay in
                        DayBoardMutations.moveTodo(todo, to: newDay)
                    }
                }

                DrawerSectionGroup(title: "drawer.section.classify") {
                    TaskDetailProjectPicker(selectedID: todo.projectID, projects: projects) { id in
                        DayBoardMutations.persist { todo.projectID = id }
                    }

                    TaskDetailTagSelector(
                        tagIDs: todo.tagIDs,
                        tags: tags,
                        onToggleTag: { tagID in
                            DayBoardMutations.persist {
                                todo.tagIDs = TagIDList.toggling(todo.tagIDs, tagID)
                            }
                        },
                        onCreateTag: { name in
                            DayBoardMutations.addTag(
                                named: name,
                                existing: tags,
                                context: modelContext,
                                ontoTodo: todo
                            )
                        }
                    )
                }

                DrawerSectionGroup(title: "drawer.section.assets") {
                    attachmentSection(ownerID: todo.id, ownerKind: .todo)

                    TaskDetailMetadataSection(
                        createdAt: todo.createdAt,
                        sourceBundleID: todo.sourceBundleID
                    )
                }
            }
            .padding(16)
        }
        .daybookScroll()
    }

    // MARK: - Routine Detail View

    private func routineDetailView(_ routine: DailyRoutine) -> some View {
        let streakResult = HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: DayClock.shared.todayKey
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TaskDetailHeaderBar(
                    isDone: false,
                    isRoutine: true,
                    onToggle: {},
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

                DrawerSectionGroup(title: "drawer.section.habit") {
                    TaskDetailTitleEditor(title: routine.title) { newTitle in
                        DayBoardMutations.persist { routine.title = newTitle }
                    }

                    TaskDetailStreakCard(streakResult: streakResult, isEnabled: routine.isEnabled)

                    TaskDetailNotesView(notes: routine.notes) { newNotes in
                        DayBoardMutations.updateNotes(for: routine, notes: newNotes)
                    }
                    .id(routine.id)
                }

                DrawerSectionGroup(title: "drawer.section.schedule") {
                    TaskDetailQuadrantGrid(
                        isImportant: routine.isImportant,
                        isUrgent: routine.isUrgent,
                        onSelect: { imp, urg in
                            DayBoardMutations.persist {
                                routine.isImportant = imp
                                routine.isUrgent = urg
                            }
                        }
                    )

                    TaskDetailRemindChips(remindMinutes: routine.remindMinutes) { minutes in
                        DayBoardMutations.setRemind(routine, minutes: minutes)
                    }

                    TaskDetailWeekdayPicker(resolvedMask: routine.resolvedWeekdayMask) { newMask in
                        DayBoardMutations.persist {
                            routine.setWeekdayMask(newMask)
                        }
                    }
                }

                DrawerSectionGroup(title: "drawer.section.classify") {
                    TaskDetailProjectPicker(selectedID: routine.projectID, projects: projects) { id in
                        DayBoardMutations.persist { routine.projectID = id }
                    }

                    TaskDetailTagSelector(
                        tagIDs: routine.tagIDs,
                        tags: tags,
                        onToggleTag: { tagID in
                            DayBoardMutations.persist {
                                routine.tagIDs = TagIDList.toggling(routine.tagIDs, tagID)
                            }
                        },
                        onCreateTag: { name in
                            DayBoardMutations.addTag(
                                named: name,
                                existing: tags,
                                context: modelContext,
                                ontoRoutine: routine
                            )
                        }
                    )
                }

                DrawerSectionGroup(title: "drawer.section.assets") {
                    attachmentSection(ownerID: routine.id, ownerKind: .routine)

                    TaskDetailMetadataSection(
                        createdAt: routine.createdAt,
                        sourceBundleID: routine.sourceBundleID
                    )
                }
            }
            .padding(16)
        }
        .daybookScroll()
    }

    private func attachmentSection(ownerID: UUID, ownerKind: AttachmentOwner) -> some View {
        let taskAttachments = attachments.filter { $0.ownerID == ownerID && $0.deletedAt == nil }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.attachments.title \(taskAttachments.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Button {
                    AttachmentActions.pickImage(ownerKind: ownerKind, ownerID: ownerID, context: modelContext)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("drawer.attachments.pick")

                Button {
                    _ = AttachmentActions.pasteImage(ownerKind: ownerKind, ownerID: ownerID, context: modelContext)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("drawer.attachments.paste")
            }

            if !taskAttachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 6)], spacing: 6) {
                    ForEach(taskAttachments) { att in
                        attachmentThumbnail(att)
                    }
                }
            }
        }
    }

    private func attachmentThumbnail(_ att: AttachmentItem) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = AttachmentStore.image(id: att.id) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
                    .onTapGesture {
                        previewAttachment = AttachmentRef(id: att.id, filename: att.filename)
                    }
            } else {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookTheme.surface)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundStyle(DaybookTheme.muted)
                    )
            }

            Button {
                DayBoardMutations.persist { att.deletedAt = .now }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            .offset(x: 3, y: -3)
        }
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

