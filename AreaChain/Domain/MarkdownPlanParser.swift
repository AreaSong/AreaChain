import Foundation

/// 解析结构化 Markdown 与免 UUID 轻量 JSON 计划，生成统一的 PlanImportDraft。
enum MarkdownPlanParser {
    private enum SectionKind: Equatable {
        case todos(dayKey: String?, tags: [String])
        case routines(tags: [String])
        case diaries(dayKey: String?, tags: [String])
    }

    private static let dateRegex = CompiledRegularExpression.make(#"\b(\d{4}-\d{2}-\d{2})\b"#)
    private static let repeatBracketRegex = CompiledRegularExpression.make(
        #"\[(?:repeat|周期|重复)\s*[:：]\s*([^\]]+)\]"#
    )
    private static let dayBracketRegex = CompiledRegularExpression.make(
        #"\[(?:day|date|日期)\s*[:：]\s*(\d{4}-\d{2}-\d{2})\]"#
    )
    private static let pinnedBracketRegex = CompiledRegularExpression.make(
        #"\[(?:pinned|pin|置顶)\]"#
    )
    private static let pausedBracketRegex = CompiledRegularExpression.make(
        #"\[(?:paused|disabled|停用|暂停)\]"#
    )

    static func parseMarkdown(_ text: String, defaultDayKey: String = DayKey.today()) throws -> PlanImportDraft {
        let lines = stripFrontmatter(from: text).components(separatedBy: .newlines)
        var state = MarkdownParseState(defaultDayKey: defaultDayKey)
        for rawLine in lines {
            state.consume(rawLine: rawLine)
        }
        state.flushPending()
        guard !state.draft.isEmpty else { throw PlanImportError.emptyPlan }
        return state.draft
    }

    static func parseJSON(_ data: Data, defaultDayKey: String = DayKey.today()) throws -> PlanImportDraft {
        let payload: LightweightPlanJSON
        do {
            payload = try JSONDecoder().decode(LightweightPlanJSON.self, from: data)
        } catch {
            throw PlanImportError.invalidFormat
        }
        let fallbackDay = payload.resolvedDefaultDay ?? defaultDayKey
        let todos = (payload.todos ?? []).map { $0.toDraft(fallbackDay: fallbackDay) }
        let routines = (payload.routines ?? []).map { $0.toDraft() }
        let diaries = (payload.diaries ?? []).map { $0.toDraft(fallbackDay: fallbackDay) }
        let draft = PlanImportDraft(
            todos: todos,
            routines: routines,
            diaries: diaries,
            tags: payload.tags ?? []
        )
        guard !draft.isEmpty else { throw PlanImportError.emptyPlan }
        return draft
    }

    // MARK: - 星期与辅助标记解析

    static func parseRepeatMask(_ spec: String) -> Int {
        let lower = spec.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty || lower == "daily" || lower == "everyday" || lower == "all" || lower == "每天" || lower == "每日" {
            return WeekdayMask.all
        }
        if lower == "workdays" || lower == "weekdays" || lower == "工作日" || lower == "周一至周五" {
            return WeekdayMask.workdays
        }
        if lower == "weekend" || lower == "weekends" || lower == "周末" {
            return calendarWeekdayBit(1) | calendarWeekdayBit(7)
        }
        let parts = lower.components(separatedBy: CharacterSet(charactersIn: ",，、/\\s").union(.whitespaces))
            .filter { !$0.isEmpty }
        var mask = 0
        for token in parts {
            if let weekday = mapWeekdayToken(token) {
                mask |= calendarWeekdayBit(weekday)
            }
        }
        return WeekdayMask.sanitized(mask)
    }

    private static func mapWeekdayToken(_ token: String) -> Int? {
        switch token {
        case "1", "mon", "monday", "周一", "星期一", "一": return 2
        case "2", "tue", "tuesday", "周二", "星期二", "二": return 3
        case "3", "wed", "wednesday", "周三", "星期三", "三": return 4
        case "4", "thu", "thursday", "周四", "星期四", "四": return 5
        case "5", "fri", "friday", "周五", "星期五", "五": return 6
        case "6", "sat", "saturday", "周六", "星期六", "六": return 7
        case "7", "0", "sun", "sunday", "周日", "周天", "星期日", "星期天", "日": return 1
        default: return nil
        }
    }

    private static func calendarWeekdayBit(_ calendarWeekday: Int) -> Int {
        guard (1...7).contains(calendarWeekday) else { return 0 }
        return 1 << (calendarWeekday - 1)
    }

    fileprivate static func extractFirstDate(in text: String) -> String? {
        let ns = text as NSString
        guard let match = dateRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        let candidate = ns.substring(with: match.range(at: 1))
        return DayKey.date(from: candidate) != nil ? candidate : nil
    }

    fileprivate static func consumeRoutineModifiers(from text: inout String) -> (mask: Int?, isEnabled: Bool) {
        var mask: Int? = nil
        var isEnabled = true
        let ns = text as NSString
        if let match = repeatBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges > 1 {
            let spec = ns.substring(with: match.range(at: 1))
            mask = parseRepeatMask(spec)
            text = (text as NSString).replacingCharacters(in: match.range, with: "")
        }
        let afterRepeat = text as NSString
        if let match = pausedBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: afterRepeat.length)) {
            isEnabled = false
            text = afterRepeat.replacingCharacters(in: match.range, with: "")
        }
        return (mask, isEnabled)
    }

    fileprivate static func consumeDiaryModifiers(from text: inout String) -> (dayKey: String?, isPinned: Bool) {
        var dayKey: String? = nil
        var isPinned = false
        let ns = text as NSString
        if let match = dayBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges > 1 {
            let candidate = ns.substring(with: match.range(at: 1))
            if DayKey.date(from: candidate) != nil { dayKey = candidate }
            text = ns.replacingCharacters(in: match.range, with: "")
        }
        let afterDay = text as NSString
        if let match = pinnedBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: afterDay.length)) {
            isPinned = true
            text = afterDay.replacingCharacters(in: match.range, with: "")
        }
        return (dayKey, isPinned)
    }

    private static func stripFrontmatter(from text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return normalized }
        let rest = normalized.dropFirst(4)
        guard let endRange = rest.range(of: "\n---\n") else { return normalized }
        return String(rest[endRange.upperBound...])
    }

    // MARK: - Markdown 状态机

    private struct MarkdownParseState {
        let defaultDayKey: String
        var section: SectionKind = .todos(dayKey: nil, tags: [])
        var draft = PlanImportDraft()
        var currentTodo: PlanTodoDraft?
        var currentRoutine: PlanRoutineDraft?
        var currentDiary: PlanDiaryDraft?
        var inCodeFence = false

        mutating func consume(rawLine: String) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inCodeFence.toggle()
                appendToActiveBody(rawLine)
                return
            }
            if inCodeFence {
                appendToActiveBody(rawLine)
                return
            }
            if trimmed.isEmpty || (trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->")) {
                return
            }
            if trimmed == "---" || trimmed == "***" {
                flushPending()
                return
            }
            if let heading = parseHeading(trimmed) {
                flushPending()
                section = heading
                return
            }
            consumeContentLine(rawLine: rawLine, trimmed: trimmed)
        }

        mutating func flushPending() {
            if let todo = currentTodo {
                draft.todos.append(todo)
                currentTodo = nil
            }
            if let routine = currentRoutine {
                draft.routines.append(routine)
                currentRoutine = nil
            }
            if let diary = currentDiary {
                draft.diaries.append(diary)
                currentDiary = nil
            }
        }

        private mutating func appendToActiveBody(_ line: String) {
            if currentTodo != nil {
                appendLine(line, to: &currentTodo!.notes)
            } else if currentRoutine != nil {
                appendLine(line, to: &currentRoutine!.notes)
            } else if currentDiary != nil {
                appendLine(line, to: &currentDiary!.text)
            }
        }

        private mutating func consumeContentLine(rawLine: String, trimmed: String) {
            let indent = indentationWidth(of: rawLine)
            switch section {
            case let .todos(dayKey, sectionTags):
                consumeTodoLine(trimmed: trimmed, indent: indent, dayKey: dayKey, sectionTags: sectionTags)
            case let .routines(sectionTags):
                consumeRoutineLine(trimmed: trimmed, indent: indent, sectionTags: sectionTags)
            case let .diaries(dayKey, sectionTags):
                consumeDiaryLine(trimmed: trimmed, indent: indent, dayKey: dayKey, sectionTags: sectionTags)
            }
        }

        private mutating func consumeTodoLine(trimmed: String, indent: Int, dayKey: String?, sectionTags: [String]) {
            if indent == 0, let item = parseListItem(trimmed) {
                flushPending()
                currentTodo = PlanTodoDraft(
                    title: item.content,
                    isDone: item.isDone,
                    dayKey: dayKey ?? defaultDayKey,
                    tagNames: sectionTags
                )
            } else if indent > 0, indent <= 4, currentTodo != nil, let sub = parseCheckboxItem(trimmed) {
                currentTodo?.subtasks.append(PlanSubtaskDraft(title: sub.content, isDone: sub.isDone))
            } else if currentTodo != nil {
                let noteLine = stripQuoteOrDeepBullet(trimmed, allowBulletStrip: indent <= 4)
                appendLine(noteLine, to: &currentTodo!.notes)
            }
        }

        private mutating func consumeRoutineLine(trimmed: String, indent: Int, sectionTags: [String]) {
            if indent == 0, let item = parseListItem(trimmed) {
                flushPending()
                var content = item.content
                let mods = MarkdownPlanParser.consumeRoutineModifiers(from: &content)
                currentRoutine = PlanRoutineDraft(
                    title: content,
                    isEnabled: mods.isEnabled,
                    weekdayMask: mods.mask,
                    tagNames: sectionTags
                )
            } else if currentRoutine != nil {
                let noteLine = stripQuoteOrDeepBullet(trimmed, allowBulletStrip: true)
                appendLine(noteLine, to: &currentRoutine!.notes)
            }
        }

        private mutating func consumeDiaryLine(trimmed: String, indent: Int, dayKey: String?, sectionTags: [String]) {
            if indent == 0, let item = parseListItem(trimmed) {
                flushPending()
                var content = item.content
                let mods = MarkdownPlanParser.consumeDiaryModifiers(from: &content)
                currentDiary = PlanDiaryDraft(
                    text: content,
                    dayKey: mods.dayKey ?? dayKey ?? defaultDayKey,
                    isPinned: mods.isPinned,
                    tagNames: sectionTags
                )
            } else if currentDiary != nil {
                let line = trimmed.hasPrefix(">") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
                appendLine(line, to: &currentDiary!.text)
            } else {
                var content = trimmed.hasPrefix(">") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
                let mods = MarkdownPlanParser.consumeDiaryModifiers(from: &content)
                currentDiary = PlanDiaryDraft(
                    text: content,
                    dayKey: mods.dayKey ?? dayKey ?? defaultDayKey,
                    isPinned: mods.isPinned,
                    tagNames: sectionTags
                )
            }
        }

        private func parseHeading(_ trimmed: String) -> SectionKind? {
            guard trimmed.hasPrefix("#") else { return nil }
            let hashes = trimmed.prefix(while: { $0 == "#" })
            guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
            let rest = trimmed.dropFirst(hashes.count)
            guard rest.first == " " || rest.first == "\t" else { return nil }
            let headingText = rest.trimmingCharacters(in: .whitespaces)
            let lower = headingText.lowercased()
            let date = MarkdownPlanParser.extractFirstDate(in: headingText)
            if lower.contains("重复事项") || lower.contains("习惯") || lower.contains("routine") || lower.contains("habit") {
                let tags = TagSyntax.names(in: headingText, includesDiaryTags: false)
                return .routines(tags: tags)
            }
            if lower.contains("手记") || lower.contains("灵感") || lower.contains("diary") || lower.contains("diaries") || lower.contains("memo") {
                let tags = TagSyntax.names(in: headingText, includesDiaryTags: true)
                return .diaries(dayKey: date, tags: tags)
            }
            let tags = TagSyntax.names(in: headingText, includesDiaryTags: false)
            if let date {
                return .todos(dayKey: date, tags: tags)
            }
            if case let .todos(existingDate, _) = section {
                return .todos(dayKey: existingDate, tags: tags)
            }
            return .todos(dayKey: nil, tags: tags)
        }

        private func indentationWidth(of rawLine: String) -> Int {
            var width = 0
            for ch in rawLine {
                if ch == " " { width += 1 }
                else if ch == "\t" { width += 4 }
                else { break }
            }
            return width
        }

        private func parseCheckboxItem(_ trimmed: String) -> (content: String, isDone: Bool)? {
            for marker in ["- [ ] ", "* [ ] ", "+ [ ] "] where trimmed.hasPrefix(marker) {
                return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), false)
            }
            for marker in ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "+ [x] ", "+ [X] "] where trimmed.hasPrefix(marker) {
                return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), true)
            }
            return nil
        }

        private func parseListItem(_ trimmed: String) -> (content: String, isDone: Bool)? {
            if let checkbox = parseCheckboxItem(trimmed) { return checkbox }
            for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
                return (String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces), false)
            }
            return nil
        }

        private func stripQuoteOrDeepBullet(_ trimmed: String, allowBulletStrip: Bool) -> String {
            if trimmed.hasPrefix(">") {
                return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if allowBulletStrip, let bullet = parseListItem(trimmed) {
                return bullet.content
            }
            return trimmed
        }

        private func appendLine(_ line: String, to target: inout String) {
            guard !line.isEmpty else { return }
            if target.isEmpty { target = line }
            else { target += "\n" + line }
        }
    }
}

// MARK: - 轻量计划 JSON 解码模型

private struct LightweightPlanJSON: Decodable {
    var day, dayKey, defaultDay: String?
    var tags: [String]?
    var todos: [JSONTodoEntry]?
    var routines: [JSONRoutineEntry]?
    var diaries: [JSONDiaryEntry]?

    var resolvedDefaultDay: String? {
        [dayKey, day, defaultDay].compactMap { $0 }.first { DayKey.date(from: $0) != nil }
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
