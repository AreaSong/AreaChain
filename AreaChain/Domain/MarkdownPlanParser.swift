import Foundation

/// 解析结构化 Markdown 与免 UUID 轻量 JSON 计划，生成统一的 PlanImportDraft。
enum MarkdownPlanParser {
    private enum SectionKind: Equatable {
        case todos(dayKey: String?, tags: [String], groupTitle: String?)
        case routines(tags: [String])
        case diaries(dayKey: String?, tags: [String])
    }

    private static let repeatBracketRegex = CompiledRegularExpression.make(
        #"(?:\[|【)(?:repeat|周期|重复)\s*[:：]\s*([^\]】]+)(?:\]|】)"#
    )
    private static let dayBracketRegex = CompiledRegularExpression.make(
        #"(?:\[|【)(?:day|date|日期)\s*[:：]\s*([^\]】]+)(?:\]|】)"#
    )
    private static let dueBracketRegex = CompiledRegularExpression.make(
        #"(?:\[|【)(?:due|截止|ddl)\s*[:：]\s*(\d{1,2}[:：]\d{2})(?:\]|】)"#
    )
    private static let pinnedBracketRegex = CompiledRegularExpression.make(
        #"(?:\[|【)(?:pinned|pin|置顶)(?:\]|】)"#
    )
    private static let pausedBracketRegex = CompiledRegularExpression.make(
        #"(?:\[|【)(?:paused|disabled|停用|暂停)(?:\]|】)"#
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
        try MarkdownPlanTableParser.decodeLightweightJSON(data, defaultDayKey: defaultDayKey)
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

    fileprivate static func hasRepeatModifier(in text: String) -> Bool {
        let ns = text as NSString
        return repeatBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    fileprivate static func shouldPromoteBulletToDiary(_ text: String) -> Bool {
        let ns = text as NSString
        if pinnedBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil {
            return true
        }
        let inlineTags = TagSyntax.names(in: text, includesDiaryTags: true)
        return inlineTags.contains(where: { DiaryMemoTags.isPresetName($0) })
    }

    fileprivate static func consumeTodoModifiers(
        from text: inout String,
        defaultDayKey: String
    ) -> (dayKey: String?, dueMinutes: Int?) {
        var dayKey: String? = nil
        var dueMinutes: Int? = nil
        let ns = text as NSString
        if let match = dayBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges > 1 {
            let candidate = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if DayKey.date(from: candidate) != nil {
                dayKey = candidate
            } else {
                dayKey = MarkdownPlanTableParser.extractFirstDate(in: candidate, defaultDayKey: defaultDayKey)
            }
            text = ns.replacingCharacters(in: match.range, with: "")
        }
        let afterDay = text as NSString
        if let match = dueBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: afterDay.length)),
           match.numberOfRanges > 1 {
            let timeToken = "@" + afterDay.substring(with: match.range(at: 1))
            dueMinutes = NaturalLanguageParser.timeMinutes(timeToken)
            text = afterDay.replacingCharacters(in: match.range, with: "")
        }
        return (dayKey, dueMinutes)
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

    fileprivate static func consumeDiaryModifiers(
        from text: inout String,
        defaultDayKey: String
    ) -> (dayKey: String?, isPinned: Bool) {
        var dayKey: String? = nil
        var isPinned = false
        let ns = text as NSString
        if let match = dayBracketRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           match.numberOfRanges > 1 {
            let candidate = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if DayKey.date(from: candidate) != nil {
                dayKey = candidate
            } else {
                dayKey = MarkdownPlanTableParser.extractFirstDate(in: candidate, defaultDayKey: defaultDayKey)
            }
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
        let unwrapped = MarkdownPlanTableParser.unwrapOuterCodeFence(text)
        let normalized = unwrapped.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return normalized }
        let rest = normalized.dropFirst(4)
        guard let endRange = rest.range(of: "\n---\n") else { return normalized }
        return String(rest[endRange.upperBound...])
    }

    // MARK: - Markdown 状态机

    private struct MarkdownParseState {
        let defaultDayKey: String
        var section: SectionKind = .todos(dayKey: nil, tags: [], groupTitle: nil)
        var draft = PlanImportDraft()
        var currentTodo: PlanTodoDraft?
        var currentRoutine: PlanRoutineDraft?
        var currentDiary: PlanDiaryDraft?
        var tableHeaders: [String]?
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
                tableHeaders = nil
                return
            }
            if trimmed == "---" || trimmed == "***" {
                flushPending()
                tableHeaders = nil
                return
            }
            if let heading = parseHeading(trimmed) {
                flushPending()
                tableHeaders = nil
                section = heading
                return
            }
            if let cells = MarkdownPlanTableParser.parseTableCells(trimmed) {
                consumeTableRow(cells: cells)
                return
            }
            tableHeaders = nil
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

        private mutating func consumeTableRow(cells: [String]) {
            if MarkdownPlanTableParser.isTableSeparator(cells) { return }
            guard let headers = tableHeaders else {
                tableHeaders = cells
                return
            }
            let sectionTags = currentSectionTags
            if let routine = MarkdownPlanTableParser.buildRoutineFromWeeklyRow(
                headers: headers, cells: cells, sectionTags: sectionTags
            ) {
                flushPending()
                draft.routines.append(routine)
                return
            }
            guard let parsed = MarkdownPlanTableParser.parseTableActionRow(headers: headers, cells: cells) else {
                return
            }
            switch section {
            case let .routines(tags):
                flushPending()
                draft.routines.append(PlanRoutineDraft(title: parsed.title, notes: parsed.note, tagNames: tags))
            case let .diaries(dayKey, tags):
                flushPending()
                let text = parsed.note.isEmpty ? parsed.title : "\(parsed.title) // \(parsed.note)"
                draft.diaries.append(PlanDiaryDraft(text: text, dayKey: dayKey ?? defaultDayKey, tagNames: tags))
            case let .todos(dayKey, tags, groupTitle):
                if let groupTitle, !MarkdownPlanTableParser.isGenericTaskHeading(groupTitle) {
                    if currentTodo == nil {
                        currentTodo = PlanTodoDraft(
                            title: groupTitle,
                            dayKey: dayKey ?? defaultDayKey,
                            tagNames: tags
                        )
                    }
                    currentTodo?.subtasks.append(PlanSubtaskDraft(title: parsed.title))
                    if !parsed.note.isEmpty {
                        appendLine("\(parsed.title)：\(parsed.note)", to: &currentTodo!.notes)
                    }
                } else {
                    flushPending()
                    draft.todos.append(PlanTodoDraft(
                        title: parsed.title,
                        dayKey: dayKey ?? defaultDayKey,
                        notes: parsed.note,
                        tagNames: tags
                    ))
                }
            }
        }

        private var currentSectionTags: [String] {
            switch section {
            case let .todos(_, tags, _), let .routines(tags), let .diaries(_, tags):
                return tags
            }
        }

        private mutating func consumeContentLine(rawLine: String, trimmed: String) {
            let indent = indentationWidth(of: rawLine)
            switch section {
            case let .todos(dayKey, sectionTags, _):
                consumeTodoLine(trimmed: trimmed, indent: indent, dayKey: dayKey, sectionTags: sectionTags)
            case let .routines(sectionTags):
                consumeRoutineLine(trimmed: trimmed, indent: indent, sectionTags: sectionTags)
            case let .diaries(dayKey, sectionTags):
                consumeDiaryLine(trimmed: trimmed, indent: indent, dayKey: dayKey, sectionTags: sectionTags)
            }
        }

        private mutating func consumeTodoLine(trimmed: String, indent: Int, dayKey: String?, sectionTags: [String]) {
            let isTopLevel = indent == 0 || (currentTodo == nil && currentRoutine == nil && currentDiary == nil)
            if isTopLevel, let item = MarkdownPlanTableParser.parseListItem(trimmed) {
                flushPending()
                var cleaned = MarkdownPlanTableParser.cleanMarkdownInline(item.content)
                if MarkdownPlanParser.hasRepeatModifier(in: cleaned) {
                    let mods = MarkdownPlanParser.consumeRoutineModifiers(from: &cleaned)
                    currentRoutine = PlanRoutineDraft(
                        title: cleaned,
                        isEnabled: mods.isEnabled,
                        weekdayMask: mods.mask,
                        tagNames: sectionTags
                    )
                    return
                }
                let isCheckbox = MarkdownPlanTableParser.parseCheckboxItem(trimmed) != nil
                if !isCheckbox && MarkdownPlanParser.shouldPromoteBulletToDiary(cleaned) {
                    let mods = MarkdownPlanParser.consumeDiaryModifiers(from: &cleaned, defaultDayKey: defaultDayKey)
                    currentDiary = PlanDiaryDraft(
                        text: cleaned,
                        dayKey: mods.dayKey ?? dayKey ?? defaultDayKey,
                        isPinned: mods.isPinned,
                        tagNames: sectionTags
                    )
                    return
                }
                let mods = MarkdownPlanParser.consumeTodoModifiers(from: &cleaned, defaultDayKey: defaultDayKey)
                currentTodo = PlanTodoDraft(
                    title: cleaned,
                    isDone: item.isDone,
                    dayKey: mods.dayKey ?? dayKey ?? defaultDayKey,
                    dueMinutes: mods.dueMinutes,
                    tagNames: sectionTags
                )
            } else if indent > 0, indent <= 4, currentTodo != nil,
                      let sub = MarkdownPlanTableParser.parseListItem(trimmed) {
                let cleaned = MarkdownPlanTableParser.cleanMarkdownInline(sub.content)
                currentTodo?.subtasks.append(PlanSubtaskDraft(title: cleaned, isDone: sub.isDone))
            } else if currentTodo != nil {
                let noteLine = stripQuoteOrDeepBullet(trimmed, allowBulletStrip: indent <= 4)
                appendLine(MarkdownPlanTableParser.cleanMarkdownInline(noteLine), to: &currentTodo!.notes)
            } else if currentRoutine != nil {
                let noteLine = stripQuoteOrDeepBullet(trimmed, allowBulletStrip: true)
                appendLine(MarkdownPlanTableParser.cleanMarkdownInline(noteLine), to: &currentRoutine!.notes)
            } else if currentDiary != nil {
                let line = trimmed.hasPrefix(">") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
                appendLine(line, to: &currentDiary!.text)
            }
        }

        private mutating func consumeRoutineLine(trimmed: String, indent: Int, sectionTags: [String]) {
            if (indent == 0 || currentRoutine == nil), let item = MarkdownPlanTableParser.parseListItem(trimmed) {
                flushPending()
                var content = MarkdownPlanTableParser.cleanMarkdownInline(item.content)
                let mods = MarkdownPlanParser.consumeRoutineModifiers(from: &content)
                currentRoutine = PlanRoutineDraft(
                    title: content,
                    isEnabled: mods.isEnabled,
                    weekdayMask: mods.mask,
                    tagNames: sectionTags
                )
            } else if currentRoutine != nil {
                let noteLine = stripQuoteOrDeepBullet(trimmed, allowBulletStrip: true)
                appendLine(MarkdownPlanTableParser.cleanMarkdownInline(noteLine), to: &currentRoutine!.notes)
            }
        }

        private mutating func consumeDiaryLine(trimmed: String, indent: Int, dayKey: String?, sectionTags: [String]) {
            if indent == 0, let item = MarkdownPlanTableParser.parseListItem(trimmed) {
                flushPending()
                var content = MarkdownPlanTableParser.cleanMarkdownInline(item.content)
                let mods = MarkdownPlanParser.consumeDiaryModifiers(from: &content, defaultDayKey: defaultDayKey)
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
                let mods = MarkdownPlanParser.consumeDiaryModifiers(from: &content, defaultDayKey: defaultDayKey)
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
            let headingText = MarkdownPlanTableParser.normalizeFullWidthSyntax(
                rest.trimmingCharacters(in: .whitespaces)
            )
            let lower = headingText.lowercased()
            let date = MarkdownPlanTableParser.extractFirstDate(in: headingText, defaultDayKey: defaultDayKey)
            if lower.contains("重复事项") || lower.contains("习惯") || lower.contains("routine") || lower.contains("habit") {
                let tags = TagSyntax.names(in: headingText, includesDiaryTags: false)
                return .routines(tags: tags)
            }
            if lower.contains("手记") || lower.contains("灵感") || lower.contains("备忘")
                || lower.contains("diary") || lower.contains("diaries") || lower.contains("memo") {
                let tags = TagSyntax.names(in: headingText, includesDiaryTags: true)
                return .diaries(dayKey: date, tags: tags)
            }
            let tags = TagSyntax.names(in: headingText, includesDiaryTags: false)
            let cleanedGroup = MarkdownPlanTableParser.cleanMarkdownInline(headingText)
            if let date {
                return .todos(dayKey: date, tags: tags, groupTitle: cleanedGroup)
            }
            if case let .todos(existingDate, _, _) = section {
                return .todos(dayKey: existingDate, tags: tags, groupTitle: cleanedGroup)
            }
            return .todos(dayKey: nil, tags: tags, groupTitle: cleanedGroup)
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

        private func stripQuoteOrDeepBullet(_ trimmed: String, allowBulletStrip: Bool) -> String {
            if trimmed.hasPrefix(">") {
                return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if allowBulletStrip, let bullet = MarkdownPlanTableParser.parseListItem(trimmed) {
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
