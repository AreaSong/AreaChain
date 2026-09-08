import SwiftData
import SwiftUI

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
    @State private var isCreatingTag = false
    @State private var newTagName = ""
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
        .background(DaybookTheme.paper.opacity(0.85))
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
                .foregroundStyle(DaybookTheme.muted.opacity(0.6))
            Text("未选中任务")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
            Text("在左侧列表中点击任意任务以查看和编辑详情")
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
            VStack(alignment: .leading, spacing: 16) {
                headerBar(
                    isDone: todo.isDone,
                    onToggle: { DayBoardMutations.toggleTodo(todo) },
                    onTrash: {
                        pendingTrash = PendingTrash(title: todo.title) {
                            DayBoardMutations.persist { todo.deletedAt = .now }
                            taskID = nil
                        }
                    }
                )

                titleSection(
                    title: todo.title,
                    onUpdate: { newTitle in
                        DayBoardMutations.editTodo(todo, title: newTitle)
                    }
                )

                Divider().opacity(0.3)

                TaskDetailNotesView(notes: todo.notes) { newNotes in
                    DayBoardMutations.updateNotes(for: todo, notes: newNotes)
                }

                Divider().opacity(0.3)

                TaskDetailSubtasksView(todo: todo)

                Divider().opacity(0.3)

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

                Divider().opacity(0.3)

                remindSection(
                    remindMinutes: todo.remindMinutes,
                    onSelectMinutes: { minutes in
                        DayBoardMutations.setRemind(todo, minutes: minutes)
                    }
                )

                scheduleDateSection(todo: todo)

                Divider().opacity(0.3)

                projectSection(
                    selectedID: todo.projectID,
                    onSelect: { id in
                        DayBoardMutations.persist { todo.projectID = id }
                    }
                )

                tagSection(
                    tagIDs: todo.tagIDs,
                    onToggleTag: { tagID in
                        DayBoardMutations.persist {
                            todo.tagIDs = TagIDList.toggling(todo.tagIDs, tagID)
                        }
                    }
                )

                Divider().opacity(0.3)

                attachmentSection(
                    ownerID: todo.id,
                    ownerKind: .todo
                )

                Divider().opacity(0.3)

                metadataSection(
                    createdAt: todo.createdAt,
                    sourceBundleID: todo.sourceBundleID
                )
            }
            .padding(16)
        }
        .daybookScroll()
    }

    // MARK: - Routine Detail View

    private func routineDetailView(_ routine: DailyRoutine) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBar(
                    isDone: false,
                    isRoutine: true,
                    onToggle: {},
                    onTrash: {
                        pendingTrash = PendingTrash(title: routine.title) {
                            DayBoardMutations.persist { routine.deletedAt = .now }
                            taskID = nil
                        }
                    }
                )

                titleSection(
                    title: routine.title,
                    onUpdate: { newTitle in
                        DayBoardMutations.persist { routine.title = newTitle }
                    }
                )

                Divider().opacity(0.3)

                TaskDetailNotesView(notes: routine.notes) { newNotes in
                    DayBoardMutations.updateNotes(for: routine, notes: newNotes)
                }

                Divider().opacity(0.3)

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

                Divider().opacity(0.3)

                remindSection(
                    remindMinutes: routine.remindMinutes,
                    onSelectMinutes: { minutes in
                        DayBoardMutations.persist { routine.remindMinutes = minutes }
                    }
                )

                weekdayMaskSection(routine: routine)

                Divider().opacity(0.3)

                projectSection(
                    selectedID: routine.projectID,
                    onSelect: { id in
                        DayBoardMutations.persist { routine.projectID = id }
                    }
                )

                tagSection(
                    tagIDs: routine.tagIDs,
                    onToggleTag: { tagID in
                        DayBoardMutations.persist {
                            routine.tagIDs = TagIDList.toggling(routine.tagIDs, tagID)
                        }
                    }
                )
            }
            .padding(16)
        }
        .daybookScroll()
    }

    // MARK: - Header Bar

    private func headerBar(
        isDone: Bool,
        isRoutine: Bool = false,
        onToggle: @escaping () -> Void,
        onTrash: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            if !isRoutine {
                InkCheckbox(isDone: isDone, action: onToggle)
                Text(isDone ? "已完成" : "待处理")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isDone ? DaybookTheme.done : DaybookTheme.ink)
            } else {
                Image(systemName: "repeat")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                Text("日常习惯")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Spacer()
            Button(action: onTrash) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("移入废纸篓")

            Button {
                taskID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("关闭面板")
        }
    }

    // MARK: - Title Section

    private func titleSection(title: String, onUpdate: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("任务名称")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)
            TextField("输入标题", text: Binding(
                get: { title },
                set: { onUpdate($0) }
            ), axis: .vertical)
            .font(.system(size: 14, weight: .medium))
            .textFieldStyle(.plain)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                    )
            )
        }
    }

    // MARK: - Remind Section

    private func remindSection(
        remindMinutes: Int?,
        onSelectMinutes: @escaping (Int?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("提醒时间")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                if let remindMinutes {
                    Text(RemindMinutes.label(remindMinutes, locale: locale))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.stamp)
                    Button {
                        onSelectMinutes(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DaybookTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 5) {
                remindChip(label: "09:00", minutes: 9 * 60, current: remindMinutes, action: onSelectMinutes)
                remindChip(label: "12:00", minutes: 12 * 60, current: remindMinutes, action: onSelectMinutes)
                remindChip(label: "15:00", minutes: 15 * 60, current: remindMinutes, action: onSelectMinutes)
                remindChip(label: "18:00", minutes: 18 * 60, current: remindMinutes, action: onSelectMinutes)
                remindChip(label: "20:00", minutes: 20 * 60, current: remindMinutes, action: onSelectMinutes)
            }
        }
    }

    private func remindChip(
        label: String,
        minutes: Int,
        current: Int?,
        action: @escaping (Int?) -> Void
    ) -> some View {
        let isSelected = current == minutes
        return Button {
            action(isSelected ? nil : minutes)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isSelected ? DaybookTheme.stamp : DaybookTheme.rule.opacity(0.25), lineWidth: 0.8)
                        )
                )
                .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule Date Section

    private func scheduleDateSection(todo: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("安排日期")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Text(DayKey.displayName(todo.dayKey, locale: locale))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DaybookTheme.stamp)
            }

            HStack(spacing: 5) {
                let todayKey = DayClock.shared.todayKey
                let tomorrowKey = DayKey.shifted(todayKey, by: 1)
                let afterTomorrowKey = DayKey.shifted(todayKey, by: 2)

                dateChip(label: "今天", key: todayKey, current: todo.dayKey) {
                    DayBoardMutations.moveTodo(todo, to: todayKey)
                }
                dateChip(label: "明天", key: tomorrowKey, current: todo.dayKey) {
                    DayBoardMutations.moveTodo(todo, to: tomorrowKey)
                }
                dateChip(label: "后天", key: afterTomorrowKey, current: todo.dayKey) {
                    DayBoardMutations.moveTodo(todo, to: afterTomorrowKey)
                }
            }
        }
    }

    private func dateChip(
        label: String,
        key: String,
        current: String,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = current == key
        return Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isSelected ? DaybookTheme.stamp : DaybookTheme.rule.opacity(0.25), lineWidth: 0.8)
                        )
                )
                .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday Mask Section (Routine)

    private func weekdayMaskSection(routine: DailyRoutine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("重复周期")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    let isSelected = (routine.resolvedWeekdayMask & (1 << (weekday - 1))) != 0
                    Button {
                        let newMask = routine.resolvedWeekdayMask ^ (1 << (weekday - 1))
                        DayBoardMutations.persist {
                            routine.weekdayMask = newMask == 0 ? 0b0111110 : newMask
                        }
                    } label: {
                        Text(weekdayShortName(weekday))
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(isSelected ? DaybookTheme.stamp : DaybookTheme.cardSurface)
                            )
                            .foregroundStyle(isSelected ? Color.white : DaybookTheme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        case 7: return "六"
        default: return ""
        }
    }

    // MARK: - Project Section

    private func projectSection(
        selectedID: UUID?,
        onSelect: @escaping (UUID?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("归属项目")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            Menu {
                Button("无项目") {
                    onSelect(nil)
                }
                ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                    Button(proj.name) {
                        onSelect(proj.id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    let name = projects.first(where: { $0.id == selectedID })?.name ?? "无项目"
                    Text(name)
                        .font(.system(size: 11))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DaybookTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                        )
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - Tag Section

    private func tagSection(
        tagIDs: String,
        onToggleTag: @escaping (UUID) -> Void
    ) -> some View {
        let activeTags = tags.filter { $0.deletedAt == nil }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("标签")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Button {
                    isCreatingTag = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("添加新标签")
            }

            if activeTags.isEmpty {
                Text("暂无标签，点击右上角「+」创建")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
                    ForEach(activeTags) { tag in
                        let isContained = TagIDList.contains(tagIDs, tag.id)
                        Button {
                            onToggleTag(tag.id)
                        } label: {
                            HStack(spacing: 2) {
                                Text("#\(tag.name)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(isContained ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.cardSurface)
                                    .overlay(
                                        Capsule()
                                            .stroke(isContained ? DaybookTheme.stamp : DaybookTheme.rule.opacity(0.25), lineWidth: 0.8)
                                    )
                            )
                            .foregroundStyle(isContained ? DaybookTheme.stamp : DaybookTheme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingTag) {
            newTagSheet
        }
    }

    private var newTagSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("创建新标签")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("标签名称", text: $newTagName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    newTagName = ""
                    isCreatingTag = false
                }
                Button("创建") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        let newTag = TagItem(name: name, sortOrder: tags.count)
                        modelContext.insert(newTag)
                        newTagName = ""
                        isCreatingTag = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    // MARK: - Attachment Section

    private func attachmentSection(
        ownerID: UUID,
        ownerKind: AttachmentOwner
    ) -> some View {
        let taskAttachments = attachments.filter { $0.ownerID == ownerID && $0.deletedAt == nil }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("附件 (\(taskAttachments.count))")
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
                .help("选择图片")

                Button {
                    _ = AttachmentActions.pasteImage(ownerKind: ownerKind, ownerID: ownerID, context: modelContext)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help("从剪贴板粘贴图片")
            }

            if !taskAttachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 6)], spacing: 6) {
                    ForEach(taskAttachments) { att in
                        let ref = AttachmentRef(id: att.id, filename: att.filename)
                        Button {
                            previewAttachment = ref
                        } label: {
                            thumbnailView(ref)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func thumbnailView(_ ref: AttachmentRef) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                )
            if let image = AttachmentStore.image(id: ref.id) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .frame(width: 56, height: 56)
    }

    private func attachmentPreviewSheet(_ item: AttachmentRef) -> some View {
        VStack(spacing: 8) {
            if let image = AttachmentStore.image(id: item.id) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400)
            }
            Text(item.filename)
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        }
        .padding(12)
    }

    // MARK: - Metadata Section

    private func metadataSection(
        createdAt: Date,
        sourceBundleID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("创建时间：\(formattedDate(createdAt))")
                .font(.system(size: 9))
                .foregroundStyle(DaybookTheme.muted.opacity(0.7))
            if !sourceBundleID.isEmpty {
                Text("来源应用：\(BundleDisplay.name(for: sourceBundleID))")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
