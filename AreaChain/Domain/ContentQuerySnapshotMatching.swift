import Foundation

/// todo 与 subtask 共用的值字段规则；字段选择和父子语义仍由各提供者负责。
enum ContentQuerySnapshotMatching {
    static func text(
        _ needle: String, excluded: Bool, fields: [(ContentQueryMatchField, String)], id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let found = fields.filter { BoardSearch.matches($0.1, needle: needle) }
        if excluded {
            guard found.isEmpty else { return nil }
            return fields.map { .init(conditionID: id, field: $0.0, kind: .absence) }
        }
        guard !found.isEmpty else { return nil }
        return found.map { field, original in
            // 不对规范化副本求偏移；Foundation 的不计变音搜索可能在组合重音前结束。
            let range = original.localizedStandardRange(of: needle).map {
                (original as NSString).rangeOfComposedCharacterSequences(for: NSRange($0, in: original))
            }
            return .init(conditionID: id, field: field, range: range)
        }
    }

    static func tag(
        _ name: String, excluded: Bool, tagIDs: String, normalizedNames: [UUID: String], id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let normalized = TagSyntax.normalizedName(name)
        let matched = TagIDList.normalized(TagIDList.parse(tagIDs)).filter { normalizedNames[$0] == normalized }
        if excluded { return matched.isEmpty ? [.init(conditionID: id, field: .tags, kind: .absence)] : nil }
        guard !matched.isEmpty else { return nil }
        return matched.map { .init(conditionID: id, field: .tags, relatedObject: .init(type: .tag, id: $0)) }
    }

    static func contains(_ interval: ContentQueryDateInterval, day: String) -> Bool {
        interval.lowerBound <= day && day <= interval.upperBound
    }
}

/// 注入快照的规范日与时间戳校验；不读当前时间，不补造缺省创建时间。
enum ContentQuerySnapshotValidation {
    static func validDay(_ key: String, dates: ContentQueryDateContext) -> Bool {
        guard CommandArgumentValidation.isCanonicalDay(key) else { return false }
        if case .success = ContentQueryDates.parse(key, context: dates) { return true }
        return false
    }

    static func validTimestamp(_ date: Date, dates: ContentQueryDateContext) -> Bool {
        // 先限制到民事日期协议可表示的年份附近，避免 Foundation 归一化坏时间戳。
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, (-62_135_769_600...253_402_473_600).contains(seconds) else { return false }
        return validDay(DayKey.from(date, calendar: dates.calendar), dates: dates)
    }
}
