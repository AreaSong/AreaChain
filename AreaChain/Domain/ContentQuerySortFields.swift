import Foundation

/// 短暂访问已公开字段以校验证据边界，不存入排序输出，不访问原始输入或父标题。
struct ContentQuerySortFields: CustomStringConvertible, CustomDebugStringConvertible {
    var fields: [(ContentQueryMatchField, String)] = []
    var tags: [DiaryQueryTag] = []
    var evidence: [ContentQueryMatchEvidence] = []
    var protectedText = false

    init(_ match: ContentQueryBatchMatch) {
        switch match {
        case .todo(let value): fields = [(.title, value.title), (.notes, value.notes)]; evidence = value.evidence
        case .subtask(let value): fields = [(.title, value.title)]; evidence = value.evidence
        case .routine(let value): fields = [(.title, value.title), (.notes, value.notes)]; evidence = value.evidence
        case .image(let value): fields = [(.filename, value.filename)]; evidence = value.evidence
        case .tag(let value): fields = [(.tagName, value.tag.name)]; evidence = value.evidence
        case .clipboard(let value): fields = [(.clipboardPlainText, value.plainText)]; evidence = value.evidence
        case .routineOccurrence(let value): evidence = value.evidence
        case .diary(let value):
            evidence = value.metadataEvidence
            switch value.presentation {
            case .publicText(let text, let bodyEvidence):
                fields = [(.diaryBody, text)]; tags = value.tags; evidence += bodyEvidence
            case .hiddenTitle: protectedText = true
            }
        case .trash(let value):
            fields = TrashQueryFields(value.object.fields).text ?? []
            evidence = value.evidence
            if case .diary(let diary) = value.object.fields,
               case .hiddenTitle = diary.presentation { protectedText = true }
        }
    }

    func text(for evidence: ContentQueryMatchEvidence) -> String? {
        guard evidence.ownerObject == nil else { return nil }
        if evidence.field == .tags {
            guard let related = evidence.relatedObject, related.type == .tag else { return nil }
            return tags.first { $0.id == related.id }?.name
        }
        guard evidence.relatedObject == nil else { return nil }
        return fields.first { $0.0 == evidence.field }?.1
    }

    func allowsAbsence(_ evidence: ContentQueryMatchEvidence) -> Bool {
        guard evidence.range == nil, evidence.ownerObject == nil, evidence.relatedObject == nil else { return false }
        return fields.contains { $0.0 == evidence.field }
            || (evidence.field == .tags && fields.contains { $0.0 == .diaryBody } && !protectedText)
    }

    /// 排序与展示共用相同的正向文字门槛；不重新搜索原文。
    func positiveText(_ evidence: ContentQueryMatchEvidence,
                      clause: ContentQuerySortContext.Clause, indexedText: NSString? = nil) -> String? {
        guard let index = evidence.alternativeIndex, clause.terms.indices.contains(index),
              evidence.kind == .positive, !clause.terms[index].excluded,
              case .text = clause.terms[index].atom,
              let original = text(for: evidence), let range = evidence.range else { return nil }
        let valid = indexedText.map { Self.valid(range, in: $0) } ?? Self.valid(range, in: original)
        guard valid else { return nil }
        return original
    }

    static func isName(_ field: ContentQueryMatchField) -> Bool { [.title, .filename, .tagName].contains(field) }

    static func valid(_ range: NSRange, in text: String) -> Bool {
        let length = text.utf16.count
        return range.location != NSNotFound && range.location >= 0 && range.length > 0
            && range.location <= length && range.length <= length - range.location && Range(range, in: text) != nil
    }

    /// 已索引的 UTF-16 字段可在一批依据内复用，避免每个命中重建长文字符串。
    static func valid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= text.length, range.length <= text.length - range.location else { return false }
        let first = text.character(at: range.location)
        let last = text.character(at: NSMaxRange(range) - 1)
        return !(0xDC00...0xDFFF).contains(first) && !(0xD800...0xDBFF).contains(last)
    }
    var description: String { "ContentQuerySortFields(redacted)" }
    var debugDescription: String { description }
}
