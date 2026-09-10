import SwiftData
import SwiftUI

// MARK: - Todo Basics Section

struct TodoBasicsSectionView: View {
    var todo: TodoItem

    var body: some View {
        DrawerSectionGroup(title: "drawer.section.basics") {
            TaskDetailTitleEditor(title: todo.title) { newTitle in
                DayBoardMutations.editTodo(todo, title: newTitle)
            }
            .id("title-\(todo.id)")

            TaskDetailNotesView(notes: todo.notes) { newNotes in
                DayBoardMutations.updateNotes(for: todo, notes: newNotes)
            }
            .id("notes-\(todo.id)")

            TaskDetailSubtasksView(todo: todo)
                .id("subtasks-\(todo.id)")
        }
    }
}

// MARK: - Todo Schedule Section

struct TodoScheduleSectionView: View {
    var todo: TodoItem

    var body: some View {
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
    }
}

// MARK: - Routine Habit Section

struct RoutineHabitSectionView: View {
    var routine: DailyRoutine
    var streakResult: StreakResult
    var boardDayKey: String
    var isDoneOnBoard: Bool
    var isSkipped: Bool

    var body: some View {
        DrawerSectionGroup(title: "drawer.section.habit") {
            TaskDetailTitleEditor(title: routine.title) { newTitle in
                DayBoardMutations.persist { routine.title = newTitle }
            }
            .id("title-\(routine.id)")

            TaskDetailStreakCard(
                config: StreakCardConfig(
                    streakResult: streakResult,
                    isEnabled: routine.isEnabled,
                    inspectDayKey: boardDayKey,
                    flags: StreakInspectionFlags(
                        isCompleted: isDoneOnBoard,
                        isSkipped: isSkipped,
                        isDue: routine.isEnabled
                            && routine.createdDayKey <= boardDayKey
                            && WeekdayMask.contains(routine.resolvedWeekdayMask, dayKey: boardDayKey)
                    )
                )
            )

            TaskDetailNotesView(notes: routine.notes) { newNotes in
                DayBoardMutations.updateNotes(for: routine, notes: newNotes)
            }
            .id("notes-\(routine.id)")
        }
    }
}

// MARK: - Routine Schedule Section

struct RoutineScheduleSectionView: View {
    var routine: DailyRoutine

    var body: some View {
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
    }
}

// MARK: - Classification Sections

struct TodoClassificationSectionView: View {
    var todo: TodoItem
    var projects: [ProjectItem]
    var tags: [TagItem]
    var modelContext: ModelContext

    var body: some View {
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
    }
}

struct RoutineClassificationSectionView: View {
    var routine: DailyRoutine
    var projects: [ProjectItem]
    var tags: [TagItem]
    var modelContext: ModelContext

    var body: some View {
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
    }
}

// MARK: - Assets Section

struct TaskDetailAssetsProps {
    var ownerID: UUID
    var ownerKind: AttachmentOwner
    var createdAt: Date
    var sourceBundleID: String?

    init(
        ownerID: UUID,
        ownerKind: AttachmentOwner,
        createdAt: Date,
        sourceBundleID: String? = nil
    ) {
        self.ownerID = ownerID
        self.ownerKind = ownerKind
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
    }
}

struct TaskDetailAssetsSectionView: View {
    var props: TaskDetailAssetsProps
    var attachments: [AttachmentItem]
    var modelContext: ModelContext
    var onPreview: (AttachmentRef) -> Void

    var body: some View {
        DrawerSectionGroup(title: "drawer.section.assets") {
            attachmentList
            TaskDetailMetadataSection(
                createdAt: props.createdAt,
                sourceBundleID: props.sourceBundleID ?? ""
            )
        }
    }

    private var attachmentList: some View {
        let taskAttachments = attachments.filter { $0.ownerID == props.ownerID && $0.deletedAt == nil }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.attachments.title \(taskAttachments.count)")
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Button {
                    AttachmentActions.pickImage(ownerKind: props.ownerKind, ownerID: props.ownerID, context: modelContext)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("drawer.attachments.pick")

                Button {
                    _ = AttachmentActions.pasteImage(ownerKind: props.ownerKind, ownerID: props.ownerID, context: modelContext)
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
                        onPreview(AttachmentRef(id: att.id, filename: att.filename))
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
                    .font(.system(size: 14))
                    .foregroundStyle(DaybookTheme.ink.opacity(0.75))
                    .background(Circle().fill(DaybookTheme.surface))
            }
            .buttonStyle(.plain)
            .padding(2)
        }
    }
}
