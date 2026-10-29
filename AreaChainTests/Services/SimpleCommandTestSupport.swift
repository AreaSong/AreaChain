import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 简单指令的隔离夹具：内存库、私有事件、计数 fake 刷新；标签指令只在这里显式打开。
@MainActor final class SimpleCommandFixture {
    let io: TaskCaptureFixture
    let handoff: HandoffFixture
    /// 三个活标签（第三个是私密标签）与一个已删除标签。
    let tags: [TagItem]
    let deleted: TagItem
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var beforeTransaction: (() throws -> Void)?
    var refreshes: [Bool] = []
    var repository: TagCommandSpecs.Repository = { SwiftDataCatalogRepository(context: $0) }
    private(set) var environment: SimpleCommandEnvironment!
    private(set) var adapter: SimpleCommandAdapter!
    var context: ModelContext { io.context }

    /// organize 为真时另装配标签整理规格；手记仓储用隔离保险箱与临时附件目录，来源证明可逐对象改为受保护。
    var protected: Set<UUID> = []
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let root = FileManager.default.temporaryDirectory.appending(path: "areachain-m2-tags-\(UUID().uuidString)", directoryHint: .isDirectory)

    init(capability: SimpleCommandAdapter.Capability = .open, isPreset: @escaping TagCommandSpecs.Preset = { $0.isDiaryPreset },
         organize: Bool = false, restore: Bool = false) throws {
        io = try TaskCaptureFixture()
        handoff = try HandoffFixture()
        tags = [TagItem(name: "工作 · Work", sortOrder: 0), TagItem(name: "家庭 · Home", sortOrder: 1, colorToken: "ink"),
                TagItem(name: "私密 · Private", sortOrder: 2, isPrivateDiary: true)]
        deleted = TagItem(name: "已删 · Gone", sortOrder: 3, deletedAt: Date(timeIntervalSince1970: 100))
        for tag in tags + [deleted] { context.insert(tag) }
        try context.save()
        var boundary = io.boundary
        boundary.save = { [unowned self] context in
            io.trace.append("save")
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        environment = try .init(context: context, center: io.center, dependencies: .init(
            transaction: boundary, validateBeforeTransaction: { [unowned self] in try beforeTransaction?() },
            registerLocalModification: { [unowned self] in io.trace.append("fact") },
            refresh: { [unowned self] includeCalendar in refreshes.append(includeCalendar) }))
        self.isPreset = isPreset
        adapter = .init(coordinator: handoff.coordinator, environment: environment,
                        specs: TagCommandSpecs.all(repository: { [unowned self] in repository($0) }, isPreset: isPreset)
                            + (organize ? TagOrganizeSpecs.all(organizing) : []) + (restore ? TrashRestoreSpec.all() : []),
                        capability: capability)
    }

    private var isPreset: TagCommandSpecs.Preset = { $0.isDiaryPreset }
    var organizing: TagOrganizeDependencies {
        .init(catalog: { [unowned self] in repository($0) },
              diaries: { [unowned self] in
                  SwiftDataDiaryRepository(context: $0, vault: vault, attachmentStore: AttachmentStore(root: root), attachmentRoot: root)
              },
              source: { [unowned self] target in
                  .init(revision: UUID(), protection: protected.contains(target.id) ? .required : .ordinary)
              }, isPreset: isPreset)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func target(_ tag: TagItem) -> CommandObjectReference { .init(type: .tag, id: tag.id) }
    func name(_ value: String) -> CommandArgument { .init(parameter: .name, operation: .assign, value: .shortText(value)) }
    func color(_ token: TagColorToken) -> CommandArgument {
        .init(parameter: .color, operation: .assign, value: .choice(token.rawValue))
    }

    func queue(_ command: String, targets: [CommandObjectReference] = [], arguments: [CommandArgument] = []) throws {
        let single = ["tag.rename", "tag.order", "tag.trash", "tag.restore", "trash.restore"].contains(command)
        let selection: CommandDraftTargets = targets.isEmpty ? .none
            : .init(targets.count == 1 && single ? .single : .selected, objects: targets)
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: selection, arguments: arguments))
    }
    func preview() throws -> CommandSimplePreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandSimpleAcceptance { try adapter.accept(preview(), expecting: handoff.owned().lease) }
    func submit(_ accepted: CommandSimpleAcceptance) throws -> CommandSimpleFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func run(_ command: String, targets: [CommandObjectReference] = [],
             arguments: [CommandArgument] = []) throws -> (CommandSimpleAcceptance, CommandSimpleFacts) {
        try queue(command, targets: targets, arguments: arguments)
        let accepted = try accept()
        return (accepted, try submit(accepted))
    }
    func count(_ action: String) -> Int { io.trace.filter { $0 == action }.count }
    func live() throws -> [TagItem] {
        try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }, sortBy: [SortDescriptor(\.sortOrder)]))
    }
    /// 同容器的新 context：读出真实落盘结果，不受当前 context 回滚缓存影响。
    func stored() throws -> [TagItem] {
        try ModelContext(io.container).fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }
}

/// 只在改名时多写一个字符：用来证明保存前核对会发现与预览不一致并整体回滚。
@MainActor final class DriftingCatalogRepository: CatalogRepositoryProtocol {
    let base: SwiftDataCatalogRepository
    init(context: ModelContext) { base = .init(context: context) }
    func fetchTags(includeDeleted: Bool) throws -> [TagItem] { try base.fetchTags(includeDeleted: includeDeleted) }
    func fetchTag(id: UUID) throws -> TagItem? { try base.fetchTag(id: id) }
    func fetchLiveTaskTags() throws -> [TagItem] { try base.fetchLiveTaskTags() }
    func createTag(name: String, sortOrder: Int?) throws -> TagItem { try base.createTag(name: name, sortOrder: sortOrder) }
    func resolveOrCreateTag(name: String) throws -> TagItem { try base.resolveOrCreateTag(name: name) }
    func resolveTaskTag(name: String) throws -> TagItem? { try base.resolveTaskTag(name: name) }
    func ensurePresetTags() throws { try base.ensurePresetTags() }
    func updateTag(id: UUID, name: String?, sortOrder: Int?, colorToken: String?) throws {
        try base.updateTag(id: id, name: name.map { $0 + "!" }, sortOrder: sortOrder, colorToken: colorToken)
    }
    func deleteTag(id: UUID, soft: Bool) throws { try base.deleteTag(id: id, soft: soft) }
    func restoreTag(id: UUID) throws { try base.restoreTag(id: id) }
    func purgeTag(id: UUID) throws { try base.purgeTag(id: id) }
    func unlinkTag(id: UUID) throws { try base.unlinkTag(id: id) }
    func reorderTags(orderedIDs: [UUID]) throws { try base.reorderTags(orderedIDs: orderedIDs) }
    func mergeTags(sourceIDs: [UUID], into targetID: UUID) throws { try base.mergeTags(sourceIDs: sourceIDs, into: targetID) }
    func batchSetColor(ids: Set<UUID>, colorToken: String) throws { try base.batchSetColor(ids: ids, colorToken: colorToken) }
    func openCount(tagID: UUID?, dayKey: String) throws -> Int { try base.openCount(tagID: tagID, dayKey: dayKey) }
}
