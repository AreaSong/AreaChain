import SwiftData
import SwiftUI

/// 工作台全局聚合搜索视图：
/// 替换主内容区，聚合展示命中的待办事项、日常习惯、手记及附件。
/// 单击条目直接在右侧抽屉（Inspector）展开详情或打开手记，保持搜索状态不丢失。
struct WorkspaceGlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Bindable var navigation = WorkspaceNavigation.shared

    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    let query: String

    private var tagMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
    }

    private var hits: [BoardSearchHit] {
        BoardSearch.hits(
            query: query,
            todos: todos.map(\.snapshot),
            diaries: diaries.map { DiaryContent.snapshot($0) },
            routines: routines.map(\.snapshot),
            todayKey: DayClock.shared.todayKey,
            tagMap: tagMap,
            privacy: BoardSearchPrivacy(
                sensitiveDiaryIDs: Set(diaries.filter { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }.map(\.id)),
                placeholder: L10n.string("diary.private.title", locale: locale)
            )
        )
    }

    private var matchingAttachments: [AttachmentItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return attachments
            .filter { AttachmentAccess.canBrowse($0, todos: todos, routines: routines, diaries: diaries, tags: tags) }
            .filter { $0.filename.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hits.isEmpty && matchingAttachments.isEmpty {
                DaybookEmptyState(
                    title: "search.empty",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // 结果总数小字说明
                        HStack {
                            Text("search.results.count \(hits.count + matchingAttachments.count)")
                                .font(DaybookType.caption.weight(.medium))
                                .foregroundStyle(DaybookTheme.muted)
                            Spacer()
                        }
                        .padding(.top, 4)

                        // 任务、习惯与手记分组
                        if !hits.isEmpty {
                            ForEach(BoardSearch.grouped(hits), id: \.dayKey) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(DayKey.displayName(group.dayKey, locale: locale))
                                        .font(DaybookType.caption.weight(.semibold))
                                        .foregroundStyle(DaybookTheme.muted)

                                    ForEach(group.items) { hit in
                                        searchHitRow(hit)
                                    }
                                }
                            }
                        }

                        // 匹配的附件
                        if !matchingAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("window.attachments")
                                    .font(DaybookType.caption.weight(.semibold))
                                    .foregroundStyle(DaybookTheme.muted)

                                ForEach(matchingAttachments) { attachment in
                                    attachmentRow(attachment)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DaybookSpacing.page)
                    .padding(.vertical, 16)
                }
                .daybookScroll()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkspaceStyle.paper)
        .accessibilityIdentifier("workspace.global.search.results")
    }

    // MARK: - Hit Row

    private func searchHitRow(_ hit: BoardSearchHit) -> some View {
        let isSelected = navigation.selectedTaskID == hit.id && navigation.isInspectorPresented
        return Button {
            openHit(hit)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(kindLabel(hit.kind))
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(DaybookTheme.stamp.opacity(0.12))
                    )

                Text(hit.title)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                    .fill(isSelected ? WorkspaceStyle.selection : WorkspaceStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                    .strokeBorder(isSelected ? DaybookTheme.stamp.opacity(0.4) : WorkspaceStyle.border, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hit.title)
    }

    // MARK: - Attachment Row

    private func attachmentRow(_ attachment: AttachmentItem) -> some View {
        Button {
            openAttachment(attachment)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperclip")
                    .foregroundStyle(DaybookTheme.stamp)

                Text(attachment.filename)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)

                Spacer()

                Text(attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                    .fill(WorkspaceStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)
                    .strokeBorder(WorkspaceStyle.border, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(attachment.filename)
    }

    // MARK: - Helpers

    private func kindLabel(_ kind: BoardSearchHit.Kind) -> LocalizedStringKey {
        switch kind {
        case .todo: "search.kind.todo"
        case .routine: "search.kind.routine"
        case .diary: "search.kind.diary"
        case .subtask: "search.kind.subtask"
        }
    }

    private func openHit(_ hit: BoardSearchHit) {
        switch hit.kind {
        case .todo, .routine:
            navigation.inspectTask(hit.id, dayKey: hit.dayKey)
        case .subtask:
            if let parentID = hit.parentID {
                navigation.inspectTask(parentID, dayKey: hit.dayKey)
            } else {
                navigation.inspectTask(hit.id, dayKey: hit.dayKey)
            }
        case .diary:
            if let entry = diaries.first(where: { $0.id == hit.id && $0.deletedAt == nil }) {
                DiaryWindows.shared.open(entry: entry, context: modelContext)
            }
        }
    }

    private func openAttachment(_ attachment: AttachmentItem) {
        guard let owner = AttachmentOwner(rawValue: attachment.ownerKind) else { return }
        switch owner {
        case .todo, .routine:
            navigation.inspectTask(attachment.ownerID)
        case .diary:
            if let entry = diaries.first(where: { $0.id == attachment.ownerID && $0.deletedAt == nil }) {
                DiaryWindows.shared.open(entry: entry, context: modelContext)
            }
        }
    }
}
