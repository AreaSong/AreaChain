import Foundation
import SwiftData

/// 手记组织（J2）——记录置顶、改日、普通标签。只有普通手记直接执行；“私密”标记、显示与遮罩
/// 在 CommandOriginalPage 里改为打开原手记页。
extension DiaryCommandSpecs {
    /// 默认不装配，只在隔离 QA 测试里显式传给 SimpleCommandAdapter。
    static func organize(_ dependencies: DiaryCommandDependencies) -> [any SimpleCommandSpec] {
        [DiaryPinnedSpec(dependencies: dependencies), DiaryMoveSpec(dependencies: dependencies),
         DiaryTagsSpec(dependencies: dependencies)]
    }
}

/// diary.pinned：记录置顶（排序），不是小窗置顶。固定多目标，每个目标调一次原仓储 setPinned，同一事务。
@MainActor struct DiaryPinnedSpec: SimpleCommandSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.pinned")
    let shape = CommandSimpleShape.fixed(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.pinned.preview", saved: "unified.simple.diary.pinned.saved")

    private func pinned(_ input: CommandResolvedInput) throws -> Bool {
        guard case .boolean(let value)? = DiaryCommandSpecs.value(input, .enabled)?.value else {
            throw CommandSimpleIssue.invalidArguments
        }
        return value
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        .init(rows: try input.targets.objects.map {
            let entry = try DiaryCommandSpecs.ordinary($0, in: context)
            return DiaryCommandSpecs.row(entry, fields: [DiaryCommandSpecs.pinnedField(entry.isPinned)])
        })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let value = try pinned(input)
        return .init(rows: before.rows.map { .init(key: $0.key, record: $0.record, title: $0.title,
                                                   fields: [DiaryCommandSpecs.pinnedField(value)]) })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let value = try pinned(input)
        let repository = dependencies.diaries(context)
        for target in input.targets.objects {
            _ = try DiaryCommandSpecs.ordinary(target, in: context)
            try repository.setPinned(id: target.id, isPinned: value)
        }
    }
}

/// diary.move：改到今天／昨天／明天／任意日（路径解析已把相对日换成民事日）；沿原菜单的 moveDiary。
@MainActor struct DiaryMoveSpec: SimpleCommandSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.move")
    let shape = CommandSimpleShape.fixed(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.move.preview", saved: "unified.simple.diary.move.saved")

    private func day(_ input: CommandResolvedInput) throws -> String {
        guard case .day(let key)? = DiaryCommandSpecs.value(input, .day)?.value, DayKey.date(from: key) != nil else {
            throw CommandSimpleIssue.invalidArguments
        }
        return key
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        .init(rows: try input.targets.objects.map {
            let entry = try DiaryCommandSpecs.ordinary($0, in: context)
            return DiaryCommandSpecs.row(entry, fields: [DiaryCommandSpecs.dayField(entry.dayKey)])
        })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let key = try day(input)
        return .init(rows: before.rows.map { .init(key: $0.key, record: $0.record, title: $0.title,
                                                   fields: [DiaryCommandSpecs.dayField(key)]) })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let key = try day(input)
        let repository = dependencies.diaries(context)
        for target in input.targets.objects {
            _ = try DiaryCommandSpecs.ordinary(target, in: context)
            try repository.moveDiary(id: target.id, to: key)
        }
    }
}

/// diary.tags（2026-10-21 用户决定，解决原未决的 privateTagTransition）：普通标签的加、减、整体替换与清空直接执行，
/// 逐个沿原菜单的 toggleTag；要加私密标签等于隐私转换，整条拒绝并引导到原手记页。移除标签不会解除已有保护
/// （产品规则），而受保护手记本就改为打开原页面。搜索不能创建标签：只接已有的活标签。
@MainActor struct DiaryTagsSpec: SimpleCommandSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.tags")
    let shape = CommandSimpleShape.fixed(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.tags.preview", saved: "unified.simple.diary.tags.saved")
    var refusesProtectedContent: Bool { true }

    /// 操作与标签 ID；clear 不带值。标签须是唯一的活标签，加入的不能是私密标签。
    private func edit(_ input: CommandResolvedInput, in context: ModelContext) throws -> (CommandFieldOperation, [UUID]) {
        guard let argument = DiaryCommandSpecs.value(input, .tags) else { throw CommandSimpleIssue.invalidArguments }
        var ids: [UUID] = []
        switch (argument.operation, argument.value) {
        case (.clear, nil): break
        case (.add, .tags(let values)?), (.remove, .tags(let values)?), (.replaceAll, .tags(let values)?): ids = values
        default: throw CommandSimpleIssue.invalidArguments
        }
        let all = try context.fetch(FetchDescriptor<TagItem>())
        for id in ids {
            let rows = all.filter { $0.id == id }
            guard rows.count == 1, rows[0].deletedAt == nil else { throw CommandSimpleIssue.invalidTarget(.missing) }
        }
        if [.add, .replaceAll].contains(argument.operation),
           DiaryWriteService.containsPrivateTag(Set(ids), tags: all) {
            throw CommandSimpleIssue.invalidTarget(.diaryPrivateTag)
        }
        return (argument.operation, ids)
    }

    /// 按原菜单的切换语义推出要切换的标签（顺序固定：先移除、再按参数顺序加入）。
    private func toggles(_ current: String, _ edit: (CommandFieldOperation, [UUID])) -> [UUID] {
        let existing = TagIDList.parse(current)
        switch edit.0 {
        case .add: return edit.1.filter { !existing.contains($0) }
        case .remove: return existing.filter { edit.1.contains($0) }
        case .replaceAll: return existing.filter { !edit.1.contains($0) } + edit.1.filter { !existing.contains($0) }
        default: return existing
        }
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        .init(rows: try input.targets.objects.map {
            let entry = try DiaryCommandSpecs.ordinary($0, in: context)
            return DiaryCommandSpecs.row(entry, fields: [
                DiaryCommandSpecs.tagsField(try DiaryCommandSpecs.tagNames(entry.tagIDs, in: context))])
        })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let edit = try edit(input, in: context)
        return .init(rows: try input.targets.objects.map { target in
            let entry = try DiaryCommandSpecs.ordinary(target, in: context)
            let final = toggles(entry.tagIDs, edit).reduce(entry.tagIDs) { TagIDList.toggling($0, $1) }
            return DiaryCommandSpecs.row(entry, fields: [DiaryCommandSpecs.tagsField(try DiaryCommandSpecs.tagNames(final, in: context))])
        })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let edit = try edit(input, in: context)
        let repository = dependencies.diaries(context)
        for target in input.targets.objects {
            let entry = try DiaryCommandSpecs.ordinary(target, in: context)
            for tagID in toggles(entry.tagIDs, edit) { try repository.toggleTag(id: entry.id, tagID: tagID) }
        }
    }
}
