import Foundation

/// 负责 Markdown 计划中的多格式日期提取、有序/无序列表识别、表格结构化解析与轻量 JSON 解码。
enum MarkdownPlanTableParser {
    private static let flexibleDateRegex = CompiledRegularExpression.make(
        #"(?<!\d)(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?(?!\d)"#
    )
    private static let numberedCheckboxRegex = CompiledRegularExpression.make(
        #"^\d+[.)、]\s*\[([ xX])\]\s+(.*)$"#
    )
    private static let numberedItemRegex = CompiledRegularExpression.make(
        #"^\d+[.)、]\s+(.*)$"#
    )
    private static let fullWidthPriorityRegex = CompiledRegularExpression.make(
        #"(?<![^\s(\[（【])！(重要紧急|紧急重要|重要且紧急|重要不紧急|不重要不紧急|不重要紧急|紧急不重要|重要|紧急|[pP][1-4])"#
    )
    private static let fullWidthTimeRegex = CompiledRegularExpression.make(
        #"(?<![^\s(\[（【])＠(\d{1,2}[:：]\d{2})"#
    )
    private static let fullWidthTagRegex = CompiledRegularExpression.make(
        #"(?<![^\s(\[（【])＃(?="|(?:[\p{L}\p{M}\p{N}_-]+))"#
    )

    static func decodeLightweightJSON(_ data: Data, defaultDayKey: String) throws -> PlanImportDraft {
        let cleanData = unwrapJSONCodeFence(data)
        if let topArray = try? JSONDecoder().decode([JSONTodoEntry].self, from: cleanData) {
            let todos = topArray.map { $0.toDraft(fallbackDay: defaultDayKey) }
            let draft = PlanImportDraft(todos: todos)
            guard !draft.isEmpty else { throw PlanImportError.emptyPlan }
            return draft
        }
        let payload: LightweightPlanJSON
        do {
            payload = try JSONDecoder().decode(LightweightPlanJSON.self, from: cleanData)
        } catch {
            throw PlanImportError.invalidFormat
        }
        let fallbackDay = payload.resolvedDefaultDay(defaultDayKey: defaultDayKey)
        let todos = payload.allTodos.map { $0.toDraft(fallbackDay: fallbackDay) }
        let routines = payload.allRoutines.map { $0.toDraft() }
        let diaries = payload.allDiaries.map { $0.toDraft(fallbackDay: fallbackDay) }
        let draft = PlanImportDraft(
            todos: todos,
            routines: routines,
            diaries: diaries,
            tags: payload.tags ?? []
        )
        guard !draft.isEmpty else { throw PlanImportError.emptyPlan }
        return draft
    }

    static func unwrapOuterCodeFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else { return text }
        let fence = String(trimmed.prefix(3))
        var lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2,
              lines.last?.trimmingCharacters(in: .whitespaces) == fence else { return text }
        let innerLines = lines.dropFirst().dropLast()
        // 只有内部不再出现同级独立闭合围栏时，才剥离最外层 AI 复制围栏
        if innerLines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == fence }) {
            return text
        }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n")
    }

    private static func unwrapJSONCodeFence(_ data: Data) -> Data {
        guard let str = String(data: data, encoding: .utf8) else { return data }
        let unwrapped = unwrapOuterCodeFence(str).trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(unwrapped.utf8)
    }

    // MARK: - 多格式与相对日期识别

    static func extractFirstDate(in text: String, defaultDayKey: String? = nil) -> String? {
        let ns = text as NSString
        let matches = flexibleDateRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches where match.numberOfRanges >= 4 {
            let year = ns.substring(with: match.range(at: 1))
            let month = Int(ns.substring(with: match.range(at: 2))) ?? 0
            let day = Int(ns.substring(with: match.range(at: 3))) ?? 0
            let candidate = String(format: "%@-%02d-%02d", year, month, day)
            if DayKey.date(from: candidate) != nil {
                return candidate
            }
        }
        guard let base = defaultDayKey else { return nil }
        let lower = text.lowercased()
        if lower.contains("后天") || lower.contains("day after tomorrow") {
            return DayKey.shifted(base, by: 2)
        }
        if lower.contains("明天") || lower.contains("明日") || lower.contains("tomorrow") {
            return DayKey.shifted(base, by: 1)
        }
        if lower.contains("昨天") || lower.contains("昨日") || lower.contains("yesterday") {
            return DayKey.shifted(base, by: -1)
        }
        if lower.contains("今天") || lower.contains("今日") || lower.contains("today") {
            return base
        }
        return nil
    }

    // MARK: - 列表项识别（支持无序列表、复选框与有序列表）

    static func parseCheckboxItem(_ trimmed: String) -> (content: String, isDone: Bool)? {
        for marker in ["- [ ] ", "* [ ] ", "+ [ ] "] where trimmed.hasPrefix(marker) {
            return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), false)
        }
        for marker in ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "+ [x] ", "+ [X] "] where trimmed.hasPrefix(marker) {
            return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), true)
        }
        let ns = trimmed as NSString
        if let match = numberedCheckboxRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges >= 3 {
            let mark = ns.substring(with: match.range(at: 1)).lowercased()
            let content = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            return (content, mark == "x")
        }
        return nil
    }

    static func parseListItem(_ trimmed: String) -> (content: String, isDone: Bool)? {
        if let checkbox = parseCheckboxItem(trimmed) { return checkbox }
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), false)
        }
        let ns = trimmed as NSString
        if let match = numberedItemRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges >= 2 {
            let content = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if !content.isEmpty { return (content, false) }
        }
        return nil
    }

    static func cleanMarkdownInline(_ text: String) -> String {
        let stripped = text.replacingOccurrences(of: "<br>", with: " / ")
            .replacingOccurrences(of: "<br/>", with: " / ")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizeFullWidthSyntax(stripped)
    }

    static func normalizeFullWidthSyntax(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        result = fullWidthPriorityRegex.stringByReplacingMatches(
            in: result,
            range: NSRange(location: 0, length: (result as NSString).length),
            withTemplate: "!$1"
        )
        result = fullWidthTimeRegex.stringByReplacingMatches(
            in: result,
            range: NSRange(location: 0, length: (result as NSString).length),
            withTemplate: "@$1"
        )
        result = fullWidthTagRegex.stringByReplacingMatches(
            in: result,
            range: NSRange(location: 0, length: (result as NSString).length),
            withTemplate: "#"
        )
        return result
    }

    // MARK: - Markdown 表格行识别与转换

    static func parseTableCells(_ trimmed: String) -> [String]? {
        guard trimmed.hasPrefix("|") else { return nil }
        var inner = trimmed.dropFirst()
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        let parts = inner.components(separatedBy: "|").map { cleanMarkdownInline($0) }
        guard parts.count >= 2 else { return nil }
        return parts
    }

    static func isTableSeparator(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty && cell.contains("-")
        }
    }

    static func isGenericTaskHeading(_ title: String) -> Bool {
        let lower = cleanMarkdownInline(title).lowercased()
        let genericKeywords = [
            "今日任务", "待办", "任务", "计划", "todo", "todos", "tasks", "plan",
            "日程", "清单", "事项", "overview", "总览"
        ]
        if extractFirstDate(in: lower) != nil { return true }
        return genericKeywords.contains { lower == $0 || lower.hasSuffix(" " + $0) }
    }

    static func extractSingleWeekdayMask(from cell: String) -> Int? {
        let cleaned = cleanMarkdownInline(cell)
        let tokens = ["周一", "周二", "周三", "周四", "周五", "周六", "周日", "周天",
                      "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日", "星期天",
                      "mon", "tue", "wed", "thu", "fri", "sat", "sun",
                      "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let lower = cleaned.lowercased()
        guard tokens.contains(lower) else { return nil }
        return MarkdownPlanParser.parseRepeatMask(lower)
    }

    static func buildRoutineFromWeeklyRow(
        headers: [String],
        cells: [String],
        sectionTags: [String]
    ) -> PlanRoutineDraft? {
        guard let first = cells.first, let mask = extractSingleWeekdayMask(from: first), cells.count >= 2 else {
            return nil
        }
        let moduleTitle = cells[1]
        guard !moduleTitle.isEmpty else { return nil }
        var noteParts: [String] = []
        for idx in 2..<cells.count {
            let val = cells[idx]
            guard !val.isEmpty, val != "—", val != "-" else { continue }
            let label = idx < headers.count ? headers[idx] : ""
            noteParts.append(label.isEmpty ? val : "\(label)：\(val)")
        }
        return PlanRoutineDraft(
            title: moduleTitle,
            isEnabled: !moduleTitle.contains("休息"),
            weekdayMask: mask,
            notes: noteParts.joined(separator: "\n"),
            tagNames: sectionTags
        )
    }

    static func parseTableActionRow(
        headers: [String],
        cells: [String]
    ) -> (title: String, note: String)? {
        let titleIndex = resolveTitleColumnIndex(headers: headers, cells: cells)
        guard titleIndex < cells.count else { return nil }
        let rawTitle = cells[titleIndex]
        guard !rawTitle.isEmpty, rawTitle != "—", rawTitle != "-" else { return nil }

        let stageIndex = headers.firstIndex { header in
            ["环节", "阶段", "分类", "模块", "部位", "stage", "phase", "category"].contains {
                header.lowercased().contains($0)
            }
        }
        let dosageIndex = headers.firstIndex { header in
            ["组数", "次数", "时长", "时间", "sets", "reps", "duration"].contains {
                header.lowercased().contains($0)
            }
        }

        var displayTitle = rawTitle
        if let sIdx = stageIndex, sIdx != titleIndex, sIdx < cells.count {
            let stage = cells[sIdx]
            if !stage.isEmpty, stage != "—", stage != "-" {
                displayTitle = "[\(stage)] \(displayTitle)"
            }
        }
        if let dIdx = dosageIndex, dIdx != titleIndex, dIdx < cells.count {
            let dosage = cells[dIdx]
            if !dosage.isEmpty, dosage != "—", dosage != "-" {
                displayTitle += "（\(dosage)）"
            }
        }

        var extraNotes: [String] = []
        for idx in 0..<cells.count {
            if idx == titleIndex || idx == stageIndex || idx == dosageIndex { continue }
            if isIndexColumn(index: idx, headers: headers, value: cells[idx]) { continue }
            let val = cells[idx]
            guard !val.isEmpty, val != "—", val != "-" else { continue }
            let header = idx < headers.count ? headers[idx] : ""
            extraNotes.append(header.isEmpty ? val : "\(header)：\(val)")
        }
        return (displayTitle, extraNotes.joined(separator: "｜"))
    }

    private static func resolveTitleColumnIndex(headers: [String], cells: [String]) -> Int {
        let primaryKeywords = ["动作", "项目", "任务", "事项", "名称", "主题", "title", "task", "item", "action", "name"]
        if let idx = headers.firstIndex(where: { h in primaryKeywords.contains(where: { h.lowercased().contains($0) }) }) {
            return idx
        }
        let secondaryKeywords = ["内容", "目标", "模块", "定位", "content", "goal", "target"]
        if let idx = headers.firstIndex(where: { h in secondaryKeywords.contains(where: { h.lowercased().contains($0) }) }) {
            return idx
        }
        for idx in 0..<cells.count where !isIndexColumn(index: idx, headers: headers, value: cells[idx]) {
            return idx
        }
        return 0
    }

    private static func isIndexColumn(index: Int, headers: [String], value: String) -> Bool {
        if index < headers.count {
            let h = headers[index].lowercased()
            if ["序号", "编号", "#", "no", "id", "index"].contains(h) { return true }
        }
        return Int(value) != nil && index == 0
    }
}

// MARK: - 轻量计划 JSON 解码模型

private struct LightweightPlanJSON: Decodable {
    var day, dayKey, defaultDay, date: String?
    var tags: [String]?
    var todos, tasks, items: [JSONTodoEntry]?
    var routines, habits: [JSONRoutineEntry]?
    var diaries, notes, memos: [JSONDiaryEntry]?

    var allTodos: [JSONTodoEntry] { (todos ?? []) + (tasks ?? []) + (items ?? []) }
    var allRoutines: [JSONRoutineEntry] { (routines ?? []) + (habits ?? []) }
    var allDiaries: [JSONDiaryEntry] { (diaries ?? []) + (notes ?? []) + (memos ?? []) }

    func resolvedDefaultDay(defaultDayKey: String) -> String {
        for raw in [dayKey, day, defaultDay, date].compactMap({ $0 }) {
            if DayKey.date(from: raw) != nil { return raw }
            if let extracted = MarkdownPlanTableParser.extractFirstDate(in: raw, defaultDayKey: defaultDayKey) {
                return extracted
            }
        }
        return defaultDayKey
    }
}

private struct JSONTodoEntry: Decodable {
    var title: String
    var isDone, done, isImportant, isUrgent: Bool?
    var day, dayKey, remind, priority, notes: String?
    var remindMinutes, dueMinutes: Int?
    var tags: [String]?
    var subtasks: [JSONSubtaskEntry]?

    func toDraft(fallbackDay: String) -> PlanTodoDraft {
        let flags = priority.flatMap { PriorityToken.flags(in: $0.hasPrefix("!") ? $0 : "!\($0)") }
        let remindVal = remindMinutes ?? remind.flatMap {
            NaturalLanguageParser.timeMinutes($0.hasPrefix("@") ? $0 : "@\($0)")
        }
        return PlanTodoDraft(
            title: title,
            isDone: isDone ?? done ?? false,
            dayKey: dayKey ?? day ?? fallbackDay,
            remindMinutes: remindVal,
            dueMinutes: dueMinutes,
            isImportant: isImportant ?? flags?.isImportant,
            isUrgent: isUrgent ?? flags?.isUrgent,
            notes: notes ?? "",
            tagNames: tags ?? [],
            subtasks: (subtasks ?? []).map { $0.toDraft() }
        )
    }
}

private struct JSONSubtaskEntry: Decodable {
    var title: String
    var isDone: Bool
    var tags: [String]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
                self.title = String(trimmed.dropFirst(4))
                self.isDone = true
            } else if trimmed.hasPrefix("[ ] ") {
                self.title = String(trimmed.dropFirst(4))
                self.isDone = false
            } else {
                self.title = trimmed
                self.isDone = false
            }
            self.tags = []
            return
        }
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try box.decode(String.self, forKey: .title)
        self.isDone = try box.decodeIfPresent(Bool.self, forKey: .isDone)
            ?? box.decodeIfPresent(Bool.self, forKey: .done)
            ?? false
        self.tags = try box.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    private enum CodingKeys: String, CodingKey { case title, isDone, done, tags }

    func toDraft() -> PlanSubtaskDraft {
        PlanSubtaskDraft(title: title, isDone: isDone, tagNames: tags)
    }
}

private struct JSONRoutineEntry: Decodable {
    var title: String
    var isEnabled, enabled, isImportant, isUrgent: Bool?
    var schedule, repeatRule, remind, priority, notes: String?
    var weekdays: [Int]?
    var remindMinutes: Int?
    var tags: [String]?

    private enum CodingKeys: String, CodingKey {
        case title, isEnabled, enabled, schedule, weekdays, remind, remindMinutes
        case priority, isImportant, isUrgent, notes, tags
        case repeatRule = "repeat"
    }

    func toDraft() -> PlanRoutineDraft {
        let flags = priority.flatMap { PriorityToken.flags(in: $0.hasPrefix("!") ? $0 : "!\($0)") }
        let remindVal = remindMinutes ?? remind.flatMap {
            NaturalLanguageParser.timeMinutes($0.hasPrefix("@") ? $0 : "@\($0)")
        }
        let mask: Int?
        if let weekdays, !weekdays.isEmpty {
            mask = MarkdownPlanParser.parseRepeatMask(weekdays.map(String.init).joined(separator: ","))
        } else if let rule = repeatRule ?? schedule {
            mask = MarkdownPlanParser.parseRepeatMask(rule)
        } else {
            mask = nil
        }
        return PlanRoutineDraft(
            title: title,
            isEnabled: isEnabled ?? enabled ?? true,
            weekdayMask: mask,
            remindMinutes: remindVal,
            isImportant: isImportant ?? flags?.isImportant,
            isUrgent: isUrgent ?? flags?.isUrgent,
            notes: notes ?? "",
            tagNames: tags ?? []
        )
    }
}

private struct JSONDiaryEntry: Decodable {
    var text, body, content, title, day, dayKey: String?
    var isPinned, pinned: Bool?
    var tags: [String]?

    func toDraft(fallbackDay: String) -> PlanDiaryDraft {
        let mainBody = text ?? body ?? content ?? ""
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fullText = trimmedTitle.isEmpty ? mainBody : (mainBody.isEmpty ? trimmedTitle : "\(trimmedTitle) // \(mainBody)")
        return PlanDiaryDraft(
            text: fullText,
            dayKey: dayKey ?? day ?? fallbackDay,
            isPinned: isPinned ?? pinned ?? false,
            tagNames: tags ?? []
        )
    }
}
