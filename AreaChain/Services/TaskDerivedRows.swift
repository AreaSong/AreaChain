import Foundation
import SwiftData

/// 备注与快速新增的派生行：文本里的 #标签 会落到哪个标签、@附件 会关联到哪个对象。
/// 读取当前状态与推出保存后状态都沿 InputTagResolver.preview／InputAttachmentResolver.matches，与写入同一规则。
@MainActor enum TaskDerivedRows {
    /// 冻结调用只读这些行；行身份按字母序，保证读取前后行顺序一致。
    static func keys(_ frozen: Set<String>?, prefix: String) -> [String]? {
        frozen.map { $0.filter { $0.hasPrefix(prefix) }.sorted() }
    }

    static func tagKeys(_ texts: [String]) -> [String] {
        let names = texts.flatMap { NaturalLanguageParser.parseTaskNotes($0).tagNames }
        return Set(names.map { "tag:" + TagSyntax.normalizedName($0) }).sorted()
    }

    static func attachmentKeys(_ text: String, owner: CommandObjectReference) -> [String] {
        Set(AttachmentSyntax.names(in: text).map { attachmentKey(owner, AttachmentSyntax.normalizedName($0)) }).sorted()
    }

    static func attachmentKey(_ owner: CommandObjectReference, _ normalized: String) -> String {
        "attachment:" + owner.id.uuidString + ":" + normalized
    }

    static func tagRow(_ key: String, title: String, live: Bool) -> CommandSimpleRow {
        .init(key: key, record: nil, title: "#" + title, fields: [
            .init(id: "tagState", value: live ? "live" : "deleted",
                  display: .localized(live ? "unified.simple.tagState.live" : "unified.simple.tagState.deleted"))])
    }

    /// 当前状态：直接用 InputTagResolver.preview（与写入同一匹配：活标签优先、否则取墓碑）；还不存在的名字没有行。
    static func tags(_ keys: [String], in context: ModelContext) throws -> [CommandSimpleRow] {
        try keys.compactMap { key in
            let normalized = String(key.dropFirst("tag:".count))
            switch try InputTagResolver.preview([normalized], in: context).first?.effect {
            case .existing(let tag)?: return tagRow(key, title: tag.name, live: true)
            case .restore(let tag)?: return tagRow(key, title: tag.name, live: false)
            case .create?, nil: return nil
            }
        }
    }

    /// L7：正文解析出的标签命中手记预置名或已有私密标签（活的或墓碑），整条指令不可执行。判定与原界面共用
    /// `InputTagResolver.protection`；差别只在结果：指令整条拒绝，原界面照常保存文字、跳过这些标签并提示。
    static func protectedTagNotices(_ names: [String], in context: ModelContext) throws -> [CommandSimpleNotice] {
        try InputTagResolver.preview(names, in: context).compactMap { name, effect in
            switch InputTagResolver.protection(name, effect) {
            case (.preset, let title)?: return .init(key: "unified.simple.notice.presetTag", title: title, blocking: true)
            case (.privateTag, let title)?: return .init(key: "unified.simple.notice.privateTag", title: title, blocking: true)
            case nil: return nil
            }
        }
    }

    /// 多目标各自解析出同一标签时只说明一次，保持首次出现的顺序。
    static func unique(_ notices: [CommandSimpleNotice]) -> [CommandSimpleNotice] {
        var seen: Set<String> = []
        return notices.filter { seen.insert($0.key + "\u{1F}" + $0.title).inserted }
    }

    static func attachmentRow(_ key: String, filename: String) -> CommandSimpleRow {
        .init(key: key, record: nil, title: "@" + filename, fields: [
            .init(id: "attachment", value: "linked", display: .localized("unified.simple.attachment.linked"))])
    }

    /// 当前状态：对象已关联同名（规范化）活附件才有行。
    static func attachments(_ keys: [String], in context: ModelContext) throws -> [CommandSimpleRow] {
        guard !keys.isEmpty else { return [] }
        let live = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))
        return keys.compactMap { key in
            let parts = key.split(separator: ":", maxSplits: 2).map(String.init)
            guard parts.count == 3, let owner = UUID(uuidString: parts[1]),
                  let item = live.first(where: { $0.ownerID == owner && AttachmentSyntax.normalizedName($0.filename) == parts[2] })
            else { return nil }
            return attachmentRow(key, filename: item.filename)
        }
    }

    /// 保存后：已关联的保持，`matches` 给出的新关联加入。
    static func expectedAttachments(_ text: String, owner: CommandObjectReference, before: CommandSimpleState,
                                    attachments: TaskNotesService.Attachments, in context: ModelContext) -> [CommandSimpleRow] {
        // 合并批 M-4：手记正文同样经 InputAttachmentResolver 关联 @附件，拥有者类型按对象类型给出。
        let kind: AttachmentOwner = owner.type == .todo ? .todo : owner.type == .diary ? .diary : .routine
        let matches = InputAttachmentResolver.matches(in: text, ownerKind: kind, ownerID: owner.id, context: context,
                                                      store: attachments.store, root: attachments.root)
        return attachmentKeys(text, owner: owner).compactMap { key in
            if let existing = before.rows.first(where: { $0.key == key }) { return existing }
            guard let match = matches.first(where: { attachmentKey(owner, AttachmentSyntax.normalizedName($0.filename)) == key })
            else { return nil }
            return attachmentRow(key, filename: match.filename)
        }
    }

    /// 多目标依次写入时，前一个对象新建的标签会被后一个对象直接使用；这里按同一顺序推出最终名字。
    @MainActor struct TagPlan {
        private var created: [String: String] = [:]
        private var titles: [String: String] = [:]

        /// 保存后每个被引用的标签都是活标签（已有、恢复或新建）。
        var rows: [CommandSimpleRow] {
            titles.sorted { $0.key < $1.key }.map { TaskDerivedRows.tagRow($0.key, title: $0.value, live: true) }
        }

        /// 返回合并后对象上的标签名字（原顺序 + 新增），沿 InputTagResolver.merging 的去重。
        mutating func merge(_ names: [String], into encoded: String, in context: ModelContext) throws -> [String] {
            var ids = TagIDList.parse(encoded)
            var result = try TaskCommandSpecs.tagNames(encoded, in: context)
            for (name, effect) in try InputTagResolver.preview(names, in: context) {
                let key = "tag:" + TagSyntax.normalizedName(name)
                switch effect {
                case .existing(let tag), .restore(let tag):
                    titles[key] = tag.name
                    if !ids.contains(tag.id) {
                        ids.append(tag.id)
                        result.append(tag.name)
                    }
                case .create:
                    let createdName = created[key] ?? name
                    created[key] = createdName
                    titles[key] = createdName
                    if !result.contains(createdName) { result.append(createdName) }
                }
            }
            return result
        }
    }
}
