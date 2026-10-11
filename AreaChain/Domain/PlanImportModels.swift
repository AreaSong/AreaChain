import Foundation

enum PlanImportError: LocalizedError, Equatable {
    case emptyPlan
    case invalidFormat

    var errorDescription: String? { message(locale: .current) }

    func message(locale: Locale) -> String {
        switch self {
        case .emptyPlan:
            return L10n.string("planImport.error.empty", locale: locale)
        case .invalidFormat:
            return L10n.string("planImport.error.format", locale: locale)
        }
    }
}

struct PlanSubtaskDraft: Equatable, Sendable {
    var title: String
    var isDone: Bool = false
    var tagNames: [String] = []
}

struct PlanTodoDraft: Equatable, Sendable {
    var title: String
    var isDone: Bool = false
    var dayKey: String? = nil
    var remindMinutes: Int? = nil
    var dueMinutes: Int? = nil
    var isImportant: Bool? = nil
    var isUrgent: Bool? = nil
    var notes: String = ""
    var tagNames: [String] = []
    var subtasks: [PlanSubtaskDraft] = []
}

struct PlanRoutineDraft: Equatable, Sendable {
    var title: String
    var isEnabled: Bool = true
    var weekdayMask: Int? = nil
    var remindMinutes: Int? = nil
    var isImportant: Bool? = nil
    var isUrgent: Bool? = nil
    var notes: String = ""
    var tagNames: [String] = []
}

struct PlanDiaryDraft: Equatable, Sendable {
    var text: String
    var dayKey: String? = nil
    var isPinned: Bool = false
    var tagNames: [String] = []
}

struct PlanImportDraft: Equatable, Sendable {
    var todos: [PlanTodoDraft] = []
    var routines: [PlanRoutineDraft] = []
    var diaries: [PlanDiaryDraft] = []
    var tags: [String] = []

    var isEmpty: Bool {
        todos.isEmpty && routines.isEmpty && diaries.isEmpty && tags.isEmpty
    }
}

struct PlanCompileContext: Equatable, Sendable {
    var existingTags: [ExportedTag] = []
    var existingTodoMaxOrders: [String: Int] = [:]
    var existingRoutineMaxOrder: Int = -1
    var dismissedDiaryPresets: Set<String> = []
    var privateDiaryTagNames: Set<String> = []
    var defaultDayKey: String
    var now: Date = .now

    init(
        existingTags: [ExportedTag] = [],
        existingTodoMaxOrders: [String: Int] = [:],
        existingRoutineMaxOrder: Int = -1,
        dismissedDiaryPresets: Set<String> = [],
        privateDiaryTagNames: Set<String> = [],
        defaultDayKey: String = DayKey.today(),
        now: Date = .now
    ) {
        self.existingTags = existingTags
        self.existingTodoMaxOrders = existingTodoMaxOrders
        self.existingRoutineMaxOrder = existingRoutineMaxOrder
        self.dismissedDiaryPresets = dismissedDiaryPresets
        self.privateDiaryTagNames = privateDiaryTagNames
        self.defaultDayKey = defaultDayKey
        self.now = now
    }
}

/// 将多格式计划草稿统一经过自然语言解析并编译为 ExportSnapshot，复用现有校验、预览与事务导入链。
enum PlanSnapshotCompiler {
    static func compile(_ draft: PlanImportDraft, context: PlanCompileContext) throws -> ExportSnapshot {
        var tags = TagAccumulator(existing: context.existingTags)
        for rawTag in draft.tags {
            _ = tags.resolve(name: rawTag, allowDiaryPreset: false)
        }
        var todoOrders = context.existingTodoMaxOrders
        let todos = draft.todos.compactMap { item -> ExportedTodo? in
            compileTodo(item, context: context, tags: &tags, orders: &todoOrders)
        }
        var routineOrder = context.existingRoutineMaxOrder
        let routines = draft.routines.compactMap { item -> ExportedRoutine? in
            compileRoutine(item, context: context, tags: &tags, maxOrder: &routineOrder)
        }
        let diaries = draft.diaries.compactMap { item -> ExportedDiary? in
            compileDiary(item, context: context, tags: &tags)
        }
        let exportedTags = tags.pendingExports
        guard !todos.isEmpty || !routines.isEmpty || !diaries.isEmpty || !exportedTags.isEmpty else {
            throw PlanImportError.emptyPlan
        }
        return ExportSnapshot(
            exportedAt: context.now,
            routines: routines,
            checks: [],
            todos: todos,
            diaries: diaries,
            tags: exportedTags,
            attachments: []
        )
    }

    private static func compileTodo(
        _ draft: PlanTodoDraft,
        context: PlanCompileContext,
        tags: inout TagAccumulator,
        orders: inout [String: Int]
    ) -> ExportedTodo? {
        let parsed = NaturalLanguageParser.parseTaskCapture(draft.title)
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let dayKey = resolvedDayKey(draft.dayKey, fallback: context.defaultDayKey)
        let nextOrder = (orders[dayKey] ?? -1) + 1
        orders[dayKey] = nextOrder
        let mergedNotes = mergeNotes(parsed: parsed.notes, explicit: draft.notes)
        let allTagNames = parsed.tagNames + extractInlineTags(from: draft.notes, allowDiary: false) + draft.tagNames
        let tagIDs = tags.resolveList(names: allTagNames, allowDiaryPreset: false)
        let subtasks = compileSubtasks(draft.subtasks, context: context, tags: &tags)
        return ExportedTodo(
            id: UUID(),
            title: title,
            isDone: draft.isDone,
            dayKey: dayKey,
            createdAt: context.now,
            remindMinutes: draft.remindMinutes ?? parsed.remindMinutes,
            dueMinutes: draft.dueMinutes,
            sortOrder: nextOrder,
            tagIDs: tagIDs,
            isImportant: draft.isImportant ?? (parsed.hasPriorityToken ? parsed.isImportant : false),
            isUrgent: draft.isUrgent ?? (parsed.hasPriorityToken ? parsed.isUrgent : false),
            notes: mergedNotes,
            subtasks: subtasks
        )
    }

    private static func compileSubtasks(
        _ items: [PlanSubtaskDraft],
        context: PlanCompileContext,
        tags: inout TagAccumulator
    ) -> [ExportedSubtask] {
        var result: [ExportedSubtask] = []
        for item in items {
            let inlineNames = TagSyntax.names(in: item.title, includesDiaryTags: false)
            let cleaned = NaturalLanguageParser.unescaped(
                TagSyntax.title(from: item.title, includesDiaryTags: false)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let tagIDs = tags.resolveList(names: inlineNames + item.tagNames, allowDiaryPreset: false)
            result.append(
                ExportedSubtask(
                    id: UUID(),
                    title: cleaned,
                    isDone: item.isDone,
                    sortOrder: result.count,
                    createdAt: context.now,
                    tagIDs: tagIDs
                )
            )
        }
        return result
    }

    private static func compileRoutine(
        _ draft: PlanRoutineDraft,
        context: PlanCompileContext,
        tags: inout TagAccumulator,
        maxOrder: inout Int
    ) -> ExportedRoutine? {
        let parsed = NaturalLanguageParser.parseTaskCapture(draft.title)
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        maxOrder += 1
        let mask = WeekdayMask.sanitized(draft.weekdayMask ?? WeekdayMask.all)
        let mergedNotes = mergeNotes(parsed: parsed.notes, explicit: draft.notes)
        let allTagNames = parsed.tagNames + extractInlineTags(from: draft.notes, allowDiary: false) + draft.tagNames
        let tagIDs = tags.resolveList(names: allTagNames, allowDiaryPreset: false)
        return ExportedRoutine(
            id: UUID(),
            title: title,
            sortOrder: maxOrder,
            isEnabled: draft.isEnabled,
            createdDayKey: context.defaultDayKey,
            weekdaysOnly: WeekdayMask.isWorkdays(mask),
            weekdayMask: mask,
            createdAt: context.now,
            remindMinutes: draft.remindMinutes ?? parsed.remindMinutes,
            tagIDs: tagIDs,
            isImportant: draft.isImportant ?? (parsed.hasPriorityToken ? parsed.isImportant : false),
            isUrgent: draft.isUrgent ?? (parsed.hasPriorityToken ? parsed.isUrgent : false),
            notes: mergedNotes
        )
    }

    private static func compileDiary(
        _ draft: PlanDiaryDraft,
        context: PlanCompileContext,
        tags: inout TagAccumulator
    ) -> ExportedDiary? {
        let parsed = NaturalLanguageParser.parseDiaryCapture(draft.text)
        guard parsed.hasContent else { return nil }
        let bodyText = resolvedDiaryText(parsed: parsed, raw: draft.text)
        guard !bodyText.isEmpty else { return nil }
        let autoTags = DiaryMemoTags.autoTagNames(in: draft.text).filter { name in
            !context.dismissedDiaryPresets.contains(TagSyntax.normalizedName(name))
        }
        let allTagNames = parsed.tagNames + draft.tagNames + autoTags
        let tagIDs = tags.resolveList(names: allTagNames, allowDiaryPreset: true)
        let dayKey = resolvedDayKey(draft.dayKey, fallback: context.defaultDayKey)
        return ExportedDiary(
            id: UUID(),
            text: bodyText,
            dayKey: dayKey,
            createdAt: context.now,
            tagIDs: tagIDs,
            isPinned: draft.isPinned
        )
    }

    private static func resolvedDiaryText(parsed: ParsedDiaryCapture, raw: String) -> String {
        if parsed.hasNoteSeparator {
            if !parsed.cleanTitle.isEmpty && !parsed.body.isEmpty {
                return "\(parsed.cleanTitle)\n\(parsed.body)"
            }
            return parsed.cleanTitle.isEmpty ? parsed.body : parsed.cleanTitle
        }
        if !parsed.body.isEmpty {
            return parsed.body
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolvedDayKey(_ candidate: String?, fallback: String) -> String {
        guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              DayKey.date(from: candidate) != nil else {
            return fallback
        }
        return candidate
    }

    private static func mergeNotes(parsed: String, explicit: String) -> String {
        let cleanExplicit = NaturalLanguageParser.unescapeSyntax(
            TagSyntax.removingTags(from: explicit, includesDiaryTags: false)
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        if parsed.isEmpty { return cleanExplicit }
        if cleanExplicit.isEmpty { return parsed }
        return "\(parsed)\n\(cleanExplicit)"
    }

    private static func extractInlineTags(from text: String, allowDiary: Bool) -> [String] {
        guard !text.isEmpty else { return [] }
        return TagSyntax.names(in: text, includesDiaryTags: allowDiary)
    }
}

private extension NaturalLanguageParser {
    static func unescaped(_ text: String) -> String {
        unescapeSyntax(text)
    }
}

/// 跟踪导入过程中的标签映射：复用已有同名活标签，缺失时自动创建新标签（待办侧仍隔离手记预置三分类）。
private struct TagAccumulator {
    private var liveByKey: [String: ExportedTag] = [:]
    private var deletedByKey: [String: ExportedTag] = [:]
    private var stagedByKey: [String: ExportedTag] = [:]
    private var stagedOrder: [String] = []
    private var nextSortOrder: Int

    init(existing: [ExportedTag]) {
        var maxOrder = -1
        for tag in existing {
            if tag.sortOrder > maxOrder { maxOrder = tag.sortOrder }
            let key = TagSyntax.normalizedName(tag.name)
            guard !key.isEmpty else { continue }
            if tag.deletedAt == nil {
                if liveByKey[key] == nil { liveByKey[key] = tag }
            } else if deletedByKey[key] == nil {
                deletedByKey[key] = tag
            }
        }
        self.nextSortOrder = maxOrder + 1
    }

    var pendingExports: [ExportedTag] {
        stagedOrder.compactMap { stagedByKey[$0] }
    }

    mutating func resolveList(names: [String], allowDiaryPreset: Bool) -> String {
        var ids: [UUID] = []
        for name in TagSyntax.uniqueNames(names) {
            if let id = resolve(name: name, allowDiaryPreset: allowDiaryPreset) {
                ids.append(id)
            }
        }
        return TagIDList.encode(TagIDList.normalized(ids))
    }

    mutating func resolve(name: String, allowDiaryPreset: Bool) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !allowDiaryPreset && DiaryMemoTags.isPresetName(trimmed) {
            return nil
        }
        let key = TagSyntax.normalizedName(trimmed)
        guard !key.isEmpty else { return nil }
        if let live = liveByKey[key] {
            return live.id
        }
        if let staged = stagedByKey[key] {
            return staged.id
        }
        if var restored = deletedByKey[key] {
            restored.deletedAt = nil
            stagedByKey[key] = restored
            stagedOrder.append(key)
            return restored.id
        }
        let created = ExportedTag(id: UUID(), name: trimmed, sortOrder: nextSortOrder)
        nextSortOrder += 1
        stagedByKey[key] = created
        stagedOrder.append(key)
        return created.id
    }
}
