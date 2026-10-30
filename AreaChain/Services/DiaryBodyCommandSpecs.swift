import Foundation
import SwiftData

/// 手记正文的两条长文指令。正文只在准备期由托管同步读宿主草稿；封存后输入只剩印记，写入只经
/// CommandLongTextEscrow.swift 里 DiaryWriteService 的借用出口。本文件是除托管文件外唯一可引用该出口的地方
/// （check_workflow 的 long-text-loan 按符号放行）。预览逐行列出会派生的标签（含手记预置分类）与 @附件。
@MainActor enum DiaryBodyRows {
    static func tagKeys(_ names: [String]) -> [String] {
        Set(names.map { "tag:" + TagSyntax.normalizedName($0) }).sorted()
    }

    /// 正文里的标签名会落到的已有标签 ID（活的或墓碑）；新建的还没有 ID，也不可能是私密标签。
    static func existingIDs(_ names: [String], in context: ModelContext) throws -> Set<UUID> {
        Set(try InputTagResolver.preview(names, in: context).compactMap { _, effect in
            switch effect {
            case .existing(let tag), .restore(let tag): return tag.id
            case .create: return nil
            }
        })
    }

    static func derived(_ frozen: Set<String>?, tagNames: () throws -> [String], text: () throws -> String,
                        owner: CommandObjectReference, in context: ModelContext) throws -> [CommandSimpleRow] {
        let tags = try TaskDerivedRows.keys(frozen, prefix: "tag:") ?? tagKeys(tagNames())
        let attachments = try TaskDerivedRows.keys(frozen, prefix: "attachment:")
            ?? TaskDerivedRows.attachmentKeys(text(), owner: owner)
        return try TaskDerivedRows.tags(tags, in: context) + TaskDerivedRows.attachments(attachments, in: context)
    }
}

/// diary.create：新建普通手记，沿手记页快速新增的“自动分类”（标题／正文分隔、#标签含预置分类）。
/// 要关联私密标签或保存后会变成受保护时整条拒绝并引导到原手记页（用户决定）。新手记身份在准备时分配一次。
@MainActor struct DiaryCreateSpec: SimpleLongTextCommandSpec, SimpleCommandCallSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.create")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.create.preview", saved: "unified.simple.diary.create.saved")
    var creates: CommandObjectType? { .diary }

    private struct Request {
        let creation: CommandObjectReference
        let day: String
        let selected: [UUID]
    }

    private func request(_ call: CommandSimpleCall) throws -> Request {
        let input = call.input
        guard let creation = call.creation, creation.type == .diary, input.targets.objects.isEmpty,
              let body = DiaryCommandSpecs.value(input, .body), body.operation == .assign,
              case .day(let day)? = DiaryCommandSpecs.value(input, .day)?.value, DayKey.date(from: day) != nil,
              input.arguments.allSatisfy({ [.body, .day, .tags].contains($0.parameter) }) else {
            throw CommandSimpleIssue.invalidArguments
        }
        var selected: [UUID] = []
        if let tags = DiaryCommandSpecs.value(input, .tags) {
            guard tags.operation == .add, case .tags(let ids)? = tags.value else { throw CommandSimpleIssue.invalidArguments }
            selected = ids
        }
        return .init(creation: creation, day: day, selected: selected)
    }

    /// 准备期的原文按快速新增拆分；封存后的印记不能取正文（正文只经借用出口）。
    private func captured(_ call: CommandSimpleCall) throws -> DiaryWriteService.Capture {
        guard case .longText(let raw)? = DiaryCommandSpecs.value(call.input, .body)?.value else {
            throw CommandSimpleIssue.invalidArguments
        }
        return DiaryWriteService.capture(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 仓储保存的正文（去首尾空白）与会合并的全部标签名（快速新增解析出的，再加保存正文里的 #标签）。
    private func names(_ capture: DiaryWriteService.Capture) -> (String, [String]) {
        let stored = capture.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (stored, capture.tagNames + TagSyntax.names(in: stored))
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let request = try request(call)
        let id = request.creation.id
        let created = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id }))
        guard created.count <= 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        var rows: [CommandSimpleRow] = []
        if let entry = created.first {
            // 新建行与预期一样不带 record：预期时还没有持久身份，写后核对只比字段。
            rows.append(.init(key: entry.id.uuidString, record: nil, title: DiaryCommandSpecs.dayTitle(entry.dayKey), fields: [
                DiaryCommandSpecs.bodyField(entry.text, dependencies.digest), DiaryCommandSpecs.dayField(entry.dayKey),
                DiaryCommandSpecs.tagsField(try DiaryCommandSpecs.tagNames(entry.tagIDs, in: context))]))
        }
        return .init(rows: try rows + DiaryBodyRows.derived(call.frozen, tagNames: { names(try captured(call)).1 },
                                                        text: { names(try captured(call)).0 },
                                                        owner: request.creation, in: context))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let request = try request(call)
        guard before.rows.allSatisfy({ $0.key != request.creation.id.uuidString }) else { throw CommandSimpleIssue.stale }
        let capture = try captured(call)
        let (stored, tagNames) = names(capture)
        guard !stored.isEmpty else { throw CommandSimpleIssue.invalidTarget(.diaryEmpty) }
        guard CommandLongTextLimit.allows(stored) else { throw CommandSimpleIssue.invalidTarget(.diaryTooLong) }
        let all = try context.fetch(FetchDescriptor<TagItem>())
        for id in request.selected {
            guard all.filter({ $0.id == id }).count == 1, all.first(where: { $0.id == id })?.deletedAt == nil else {
                throw CommandSimpleIssue.invalidTarget(.missing)
            }
        }
        guard !DiaryWriteService.containsPrivateTag(Set(request.selected), tags: all),
              !DiaryWriteService.capturesPrivateTag(capture, tags: all) else {
            throw CommandSimpleIssue.invalidTarget(.diaryPrivateTag)
        }
        let ids = Set(request.selected).union(try DiaryBodyRows.existingIDs(tagNames, in: context))
        guard !DiaryWriteService.becomesProtected(text: stored, tagIDs: ids, tags: all) else {
            throw CommandSimpleIssue.invalidTarget(.protectedDiary)
        }
        var plan = TaskDerivedRows.TagPlan()
        let merged = try plan.merge(tagNames, into: TagIDList.encode(request.selected), in: context)
        let row = CommandSimpleRow(key: request.creation.id.uuidString, record: nil, title: DiaryCommandSpecs.dayTitle(request.day), fields: [
            DiaryCommandSpecs.bodyField(stored, dependencies.digest), DiaryCommandSpecs.dayField(request.day),
            DiaryCommandSpecs.tagsField(merged)])
        let attachments = TaskDerivedRows.expectedAttachments(stored, owner: request.creation, before: before,
                                                              attachments: dependencies.attachments, in: context)
        return .init(rows: [row] + plan.rows + attachments)
    }

    /// 唯一写入：托管签发的借用交给 DiaryWriteService 的出口。
    func apply(_ call: CommandSimpleCall, loan: CommandLongTextLoan, in context: ModelContext) throws {
        let request = try request(call)
        try DiaryWriteService.applyLent(loan, creating: .init(id: request.creation.id, dayKey: request.day,
                                                              tagIDs: Set(request.selected)),
                                        repository: dependencies.diaries(context), in: context)
    }

    /// 回执“打开新手记”：沿结果打开的同一解析。
    func openTarget(_ creation: CommandObjectReference) -> ContentQueryBrowseOpen? {
        creation.type == .diary ? .init(object: creation, parent: nil, viewingTrash: false) : nil
    }
}

/// diary.body：普通手记全文替换或追加（clear 因目录 body 不允许空值，在静态校验就被拒），沿原 editDiary：
/// 合并正文里的 #标签、关联 @附件。冲突基线是正文的带键摘要与标签；已有正文超过 64KiB、目标受保护、
/// 改写后会变成受保护，都改为打开原手记页。走共用独立确认（目录要求），只能单项。
@MainActor struct DiaryBodySpec: SimpleLongTextCommandSpec, SimpleCommandCallSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.body")
    let shape = CommandSimpleShape.single(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.body.preview", saved: "unified.simple.diary.body.saved")
    var confirms: Bool { true }
    var refusesProtectedContent: Bool { true }

    private func target(_ call: CommandSimpleCall, in context: ModelContext) throws -> DiaryEntry {
        let arguments = TagCommandSpecs.arguments(call.input)
        guard arguments.count == 1, let argument = arguments.first, argument.parameter == .body,
              [.replace, .append].contains(argument.operation), call.input.targets.objects.count == 1 else {
            throw CommandSimpleIssue.invalidArguments
        }
        let entry = try DiaryCommandSpecs.ordinary(call.input.targets.objects[0], in: context)
        guard CommandLongTextLimit.allows(entry.text) else { throw CommandSimpleIssue.invalidTarget(.diaryTooLong) }
        return entry
    }

    /// 准备期的原文推出改写后的全文；封存后的印记不能取正文。
    private func final(_ call: CommandSimpleCall, _ entry: DiaryEntry) throws -> String {
        guard let argument = TagCommandSpecs.arguments(call.input).first, case .longText(let text)? = argument.value else {
            throw CommandSimpleIssue.invalidArguments
        }
        return try DiaryWriteService.BodyEdit(argument.operation, text: text).final(entry.text)
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let entry = try target(call, in: context)
        let owner = call.input.targets.objects[0]
        let row = CommandSimpleRow(key: entry.id.uuidString, record: entry.persistentModelID,
                                   title: DiaryCommandSpecs.dayTitle(entry.dayKey), fields: [
            DiaryCommandSpecs.bodyField(entry.text, dependencies.digest),
            DiaryCommandSpecs.tagsField(try DiaryCommandSpecs.tagNames(entry.tagIDs, in: context))])
        return .init(rows: try [row] + DiaryBodyRows.derived(call.frozen, tagNames: { TagSyntax.names(in: try final(call, entry)) },
                                                         text: { try final(call, entry) }, owner: owner, in: context))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let entry = try target(call, in: context)
        let text = try final(call, entry)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CommandSimpleIssue.invalidTarget(.diaryEmpty) }
        guard CommandLongTextLimit.allows(text) else { throw CommandSimpleIssue.invalidTarget(.diaryTooLong) }
        let names = TagSyntax.names(in: text)
        let ids = Set(TagIDList.parse(entry.tagIDs)).union(try DiaryBodyRows.existingIDs(names, in: context))
        guard !DiaryWriteService.becomesProtected(text: text, tagIDs: ids, tags: try context.fetch(FetchDescriptor<TagItem>())) else {
            throw CommandSimpleIssue.invalidTarget(.diaryPrivateTag)
        }
        var plan = TaskDerivedRows.TagPlan()
        let merged = try plan.merge(names, into: entry.tagIDs, in: context)
        let owner = call.input.targets.objects[0]
        let row = CommandSimpleRow(key: entry.id.uuidString, record: entry.persistentModelID, title: DiaryCommandSpecs.dayTitle(entry.dayKey),
                                   fields: [DiaryCommandSpecs.bodyField(text, dependencies.digest), DiaryCommandSpecs.tagsField(merged)])
        let attachments = TaskDerivedRows.expectedAttachments(text, owner: owner, before: before,
                                                              attachments: dependencies.attachments, in: context)
        return .init(rows: [row] + plan.rows + attachments.sorted { $0.key < $1.key })
    }

    /// 唯一写入：托管签发的借用交给 DiaryWriteService 的出口（出口在取正文前再判一次保护）。
    func apply(_ call: CommandSimpleCall, loan: CommandLongTextLoan, in context: ModelContext) throws {
        let entry = try DiaryCommandSpecs.ordinary(call.input.targets.objects[0], in: context)
        try DiaryWriteService.applyLent(loan, editing: entry, repository: dependencies.diaries(context), in: context)
    }
}
