import SwiftData
import SwiftUI

/// 工作台全局聚合搜索视图：
/// 替换主内容区，聚合展示命中的待办事项、日常习惯、手记及附件。
/// 单击条目直接在右侧抽屉（Inspector）展开详情或打开手记，保持搜索状态不丢失。
struct WorkspaceGlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Bindable var navigation = WorkspaceNavigation.shared
    @Bindable private var filterSession = BoardFilterSession.shared

    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    /// 可浏览附件必须未删除；拥有者列表仍整表拉取，否则 `isSingleLive` 看不到重复 UUID。
    @Query(filter: Self.attachmentQuery) private var attachments: [AttachmentItem]

    /// 测试锁住 `@Query` 形状：必须是活附件 predicate，不能改回整表。
    static var attachmentQuery: Predicate<AttachmentItem> { SoftDelete.liveAttachments }

    let query: String

    var body: some View {
        let page = makeSearchPage()
        VStack(alignment: .leading, spacing: 0) {
            if page.isEmpty {
                DaybookEmptyState(
                    title: "search.empty",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("search.results.count \(page.resultCount)")
                                .font(DaybookType.caption.weight(.medium))
                                .foregroundStyle(DaybookPalette.text.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)

                        if !page.hits.isEmpty {
                            BoardSearchHitGroups(
                                hits: page.hits,
                                presentation: .workspace,
                                sectionSpacing: 20,
                                rowSpacing: 8,
                                isSelected: { navigation.selectedTaskID == $0.id && navigation.isInspectorPresented },
                                isHighlighted: { hit in
                                    let ordered = SearchResultOrder.flat(page.hits)
                                    guard let index = navigation.searchResultIndex, ordered.indices.contains(index) else { return false }
                                    let current = ordered[index]
                                    return current.id == hit.id && current.kind == hit.kind && current.dayKey == hit.dayKey
                                },
                                open: openHit
                            )
                        }

                        if !page.matchingAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("window.attachments")
                                    .font(DaybookType.caption.weight(.semibold))
                                    .foregroundStyle(DaybookPalette.text.secondary)

                                ForEach(page.matchingAttachments) { attachment in
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
        .background(DaybookPalette.fill.page)
        .accessibilityIdentifier("workspace.global.search.results")
        .workspaceInspectorTargets(page.inspectorIDs)
        .modifier(SearchResultKeys(
            hits: page.hits,
            index: $navigation.searchResultIndex,
            onOpen: openHit,
            onComplete: { SearchHitCommands.complete($0, context: modelContext) },
            onLeaveToField: { navigation.focusSearch() }
        ))
    }

    private func makeSearchPage() -> WorkspaceSearchPageModel {
        WorkspaceSearchPageModel.make(
            query: query,
            sources: WorkspaceSearchSources(
                todos: todos,
                diaries: diaries,
                routines: routines,
                checks: checks,
                tags: tags,
                attachments: attachments
            ),
            filter: filterSession.globalSearchFilter,
            todayKey: DayClock.shared.todayKey,
            locale: locale
        )
    }

    /// 附件文件名只在工作台顶部搜索里匹配可浏览附件，不是 `BoardSearch` 的产品范围。
    /// 菜单栏不查文件名，避免把局部行为扩成统一搜索契约。
    /// 待办/手记/习惯的 `@Query` 必须含墓碑，才能按 `isSingleLive` 判重复 UUID。
    /// 附件已用 live predicate；工作台顶栏一次 body 只建一份 `ownerIndex`。
    private func attachmentRow(_ attachment: AttachmentItem) -> some View {
        Button {
            openAttachment(attachment)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperclip")
                    .foregroundStyle(DaybookPalette.accent.base)

                Text(attachment.filename)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)

                Spacer()

                Text(attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .daybookSurface(.row, configure: { $0.radius = DaybookRadius.regular })
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 附件结果整行点击区
        .help(attachment.filename)
    }

    // MARK: - Helpers

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
        switch AttachmentOwner(rawValue: attachment.ownerKind) {
        case .todo:
            guard let todo = todos.first(where: { $0.id == attachment.ownerID && $0.deletedAt == nil }) else { return }
            if let target = WorkspaceAttachmentQuery.inspectionTarget(
                ownerKind: attachment.ownerKind,
                ownerID: attachment.ownerID,
                todos: [todo.snapshot],
                routines: [],
                todayKey: DayClock.shared.todayKey
            ) {
                navigation.inspectTask(target.id, dayKey: target.dayKey)
            }
        case .routine:
            guard let routine = routines.first(where: { $0.id == attachment.ownerID && $0.deletedAt == nil }) else { return }
            if let target = WorkspaceAttachmentQuery.inspectionTarget(
                ownerKind: attachment.ownerKind,
                ownerID: attachment.ownerID,
                todos: [],
                routines: [routine.snapshot],
                todayKey: DayClock.shared.todayKey
            ) {
                navigation.inspectTask(target.id, dayKey: target.dayKey)
            }
        case .diary:
            guard let entry = diaries.first(where: { $0.id == attachment.ownerID && $0.deletedAt == nil }) else { return }
            DiaryWindows.shared.open(entry: entry, context: modelContext)
        case nil:
            return
        }
    }
}

/// 文件名只吃文字关键词。标签、优先级和时刻留给事项结果，不要求出现在文件名里。
enum WorkspaceAttachmentQuery {
    static func matches(filename: String, query: String) -> Bool {
        matches(filename: filename, keywords: BoardSearch.parseQuery(query).textKeywords)
    }

    static func matches(filename: String, keywords: [String]) -> Bool {
        guard !keywords.isEmpty else { return false }
        return keywords.allSatisfy { BoardSearch.matches(filename, needle: $0) }
    }

    /// 附件结果没有自己的命中日。一次性事项用事项日，重复事项用真实检查日，不用当前页面日期代替。
    static func inspectionTarget(
        ownerKind: String,
        ownerID: UUID,
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> (id: UUID, dayKey: String)? {
        switch AttachmentOwner(rawValue: ownerKind) {
        case .todo:
            guard let todo = todos.first(where: { $0.id == ownerID && $0.deletedAt == nil }),
                  DayKey.date(from: todo.dayKey, calendar: calendar) != nil else { return nil }
            return (todo.id, todo.dayKey)
        case .routine:
            guard let routine = routines.first(where: { $0.id == ownerID && $0.deletedAt == nil }) else { return nil }
            return (
                routine.id,
                AgendaProjection.inspectionDay(for: routine, todayKey: todayKey, calendar: calendar)
            )
        case .diary, nil:
            return nil
        }
    }
}
