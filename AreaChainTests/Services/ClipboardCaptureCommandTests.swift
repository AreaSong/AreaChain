import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 写入附件文件后抛错：检验失败时不留孤儿文件。其余调用转给注入根目录的 AttachmentStore。
final class FailingAttachmentStorage: AttachmentStorageProtocol, @unchecked Sendable {
    let base: AttachmentStore
    init(root: URL) { base = AttachmentStore(root: root) }
    func directory(fileManager: FileManager) -> URL { base.directory(fileManager: fileManager) }
    func fileURL(id: UUID, root: URL?) -> URL { base.fileURL(id: id, root: root) }
    func save(data: Data, filename: String, ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
              root: URL?, id: UUID, createdAt: Date) throws -> AttachmentItem {
        _ = try base.save(data: data, filename: filename, ownerKind: ownerKind, ownerID: ownerID, context: context,
                          root: root, id: id, createdAt: createdAt)
        throw TaskCreateCommandIO.Failure.injected
    }
    func loadData(id: UUID, root: URL?) -> Data? { base.loadData(id: id, root: root) }
    func removeFile(id: UUID, root: URL?) { base.removeFile(id: id, root: root) }
    func purge(ownerID: UUID, attachments: [AttachmentItem], context: ModelContext, root: URL?) {
        base.purge(ownerID: ownerID, attachments: attachments, context: context, root: root)
    }
    func resetDirectory(fileManager: FileManager) throws { try base.resetDirectory(fileManager: fileManager) }
}

/// 剪贴板加今天的共享入口与抽取前算法逐字等价；capture.clipboard 预览不读剪贴板、提交只读一次。
@Suite(.serialized) @MainActor struct ClipboardCaptureCommandTests {
    @MainActor final class Fixture {
        let io: TaskCaptureFixture
        let handoff: HandoffFixture
        let root: URL
        var contents = ClipboardCapture.Contents()
        var reads = 0
        var refreshes: [Bool] = []
        var saveMode = TaskCreateCommandIO.SaveMode.normal
        var storage: any AttachmentStorageProtocol
        private(set) var adapter: ClipboardCaptureCommandAdapter!

        init() throws {
            io = try TaskCaptureFixture()
            handoff = try HandoffFixture()
            root = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-clip-\(UUID().uuidString)",
                                                                    directoryHint: .isDirectory)
            storage = AttachmentStore(root: root)
            var boundary = io.boundary
            boundary.save = { [unowned self] context in
                io.trace.append("save")
                if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
                try context.save()
                if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
            }
            let environment = try ClipboardCaptureCommandEnvironment(context: io.context, center: io.center,
                capture: capture, stampsSource: { true }, transaction: boundary)
            environment.refresh = { [unowned self] in refreshes.append($0) }
            adapter = .init(coordinator: handoff.coordinator, environment: environment)
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        var capture: ClipboardCapture.Environment {
            .init(read: { [unowned self] in reads += 1; return contents }, storage: StorageProxy(owner: self),
                  locale: { Locale(identifier: "zh-Hans") }, today: { TaskSimpleFixture.today },
                  sourceBundleID: { "qa.source.app" })
        }

        func start(_ draft: CommandDraft? = nil) throws {
            try handoff.start(draft ?? .init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "capture.clipboard")))
        }
        func draft() throws -> CommandDraftStamp { try #require(handoff.state().operations.active?.stamp) }
        func prepare() throws -> CommandClipboardCapturePreview {
            try adapter.prepare(draft: draft(), expecting: handoff.owned().lease)
        }
        func submit(_ preview: CommandClipboardCapturePreview) throws -> CommandClipboardCaptureFacts {
            try adapter.submit(preview, expecting: handoff.owned().lease)
        }
        func files() -> [String] { (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [] }
        func todos() throws -> [TodoItem] { try ModelContext(io.container).fetch(FetchDescriptor<TodoItem>()) }
    }

    /// 让夹具中途替换存储（例如换成写入失败的存储）而不重建环境。
    final class StorageProxy: AttachmentStorageProtocol, @unchecked Sendable {
        unowned let owner: Fixture
        init(owner: Fixture) { self.owner = owner }
        private var base: any AttachmentStorageProtocol { MainActor.assumeIsolated { owner.storage } }
        func directory(fileManager: FileManager) -> URL { base.directory(fileManager: fileManager) }
        func fileURL(id: UUID, root: URL?) -> URL { base.fileURL(id: id, root: root) }
        func save(data: Data, filename: String, ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
                  root: URL?, id: UUID, createdAt: Date) throws -> AttachmentItem {
            try base.save(data: data, filename: filename, ownerKind: ownerKind, ownerID: ownerID, context: context,
                          root: root, id: id, createdAt: createdAt)
        }
        func loadData(id: UUID, root: URL?) -> Data? { base.loadData(id: id, root: root) }
        func removeFile(id: UUID, root: URL?) { base.removeFile(id: id, root: root) }
        func purge(ownerID: UUID, attachments: [AttachmentItem], context: ModelContext, root: URL?) {
            base.purge(ownerID: ownerID, attachments: attachments, context: context, root: root)
        }
        func resetDirectory(fileManager: FileManager) throws { try base.resetDirectory(fileManager: fileManager) }
    }

    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    /// 抽取前的 ingest 逐字副本（只把剪贴板、标题语言、日期、来源与存储换成参数）。
    private static func legacyIngest(container: ModelContainer, text: String?, image: NSImage?, storage: any AttachmentStorageProtocol,
                                     today: String, stamp: String) -> Bool {
        let imageTitle = L10n.string("capture.image", locale: Locale(identifier: "zh-Hans"))
        guard let payload = ClipboardPayload.make(text: text, hasImage: image != nil, imageTitle: imageTitle) else { return false }
        let context = container.mainContext
        let todo = TodoItem(title: payload.title, dayKey: today, sourceBundleID: stamp)
        let attachmentID = UUID()
        let saved = ModelChanges.perform(in: context) {
            let names = TagSyntax.names(in: payload.title, includesDiaryTags: false)
            todo.tagIDs = try TaskSimpleCommandLegacyRules.merging(names, into: "", in: context)
            context.insert(todo)
            if payload.attachImage {
                guard let image, let data = ImageBytes.png(from: image) else { throw ScreenCaptureFailure.encode }
                if let concreteStore = storage as? AttachmentStore {
                    _ = try AttachmentPoolStore.saveOrLink(data: data, filename: "paste.png", ownerKind: .todo,
                                                           ownerID: todo.id, context: context, store: concreteStore, id: attachmentID)
                } else {
                    let existing = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments)))?
                        .map(\.filename) ?? []
                    let resolvedName = AttachmentSyntax.uniqueFilename(base: "paste.png", existing: existing)
                    _ = try storage.save(data: data, filename: resolvedName, ownerKind: .todo, ownerID: todo.id,
                                         context: context, id: attachmentID)
                }
            }
        }
        if !saved, payload.attachImage { storage.removeFile(id: attachmentID) }
        return saved
    }

    private static func snapshot(_ container: ModelContainer, root: URL) throws -> [String] {
        let reader = ModelContext(container)
        let tags = try reader.fetch(FetchDescriptor<TagItem>())
        let todos = try reader.fetch(FetchDescriptor<TodoItem>())
        let links = try reader.fetch(FetchDescriptor<AttachmentItem>())
        let files = (try? FileManager.default.contentsOfDirectory(atPath: root.path).filter { !$0.hasPrefix(".") }.count) ?? 0
        return todos.map { todo in
            [todo.title, todo.dayKey, todo.sourceBundleID, todo.notes, "\(String(describing: todo.remindMinutes))",
             "\(todo.isImportant)\(todo.isUrgent)",
             TagIDList.parse(todo.tagIDs).map { id in tags.first { $0.id == id }?.name ?? "?" }.joined(separator: ",")].joined(separator: "|")
        } + links.map(\.filename) + tags.map(\.name).sorted() + ["files:\(files)"]
    }

    nonisolated static let cases: [(String?, Bool)] = [("原文 #工作 !p1 @09:00 明天", false), ("有图也只取文字 #标签", true),
                                                        (nil, true), ("   ", false), ("#密码 预置不解析", false)]

    @Test(arguments: 0..<cases.count)
    func sharedEntryMatchesPreExtractionAlgorithm(_ index: Int) throws {
        let (text, hasImage) = Self.cases[index]
        let image = hasImage ? Self.image() : nil
        let legacy = try TaskCaptureFixture()
        let shared = try TaskCaptureFixture()
        let legacyRoot = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-legacy-\(UUID().uuidString)")
        let sharedRoot = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-shared-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: legacyRoot); try? FileManager.default.removeItem(at: sharedRoot) }
        let legacySaved = Self.legacyIngest(container: legacy.container, text: text, image: image,
                                            storage: AttachmentStore(root: legacyRoot), today: TaskSimpleFixture.today, stamp: "qa.app")
        let sharedSaved = ClipboardCapture.ingest(container: shared.container, environment: .init(
            read: { .init(text: text, image: image) }, storage: AttachmentStore(root: sharedRoot),
            locale: { Locale(identifier: "zh-Hans") }, today: { TaskSimpleFixture.today }, sourceBundleID: { "qa.app" }))
        #expect(sharedSaved == legacySaved)
        #expect(try Self.snapshot(shared.container, root: sharedRoot) == Self.snapshot(legacy.container, root: legacyRoot))
    }

    /// 原签名入口仍读传入的剪贴板；菜单栏调用不变。这里用私有剪贴板与临时附件目录，不碰系统剪贴板。
    /// 指令遇到私密标签整条不写，并逐个说明；原界面入口（同一 ClipboardCapture.apply）仍跳过标签照常保存。
    @Test func commandRejectsPrivateTagWhileSharedEntrySkipsIt() throws {
        let f = try Fixture()
        f.io.context.insert(TagItem(name: "私账", sortOrder: 0, isPrivateDiary: true))
        try f.io.context.save()
        f.contents = .init(text: "报销 #私账", image: Self.image())
        try f.start()
        let facts = try f.submit(f.prepare())
        #expect(facts.state == .protectedTag && facts.attachedImage == false)
        #expect(facts.protectedTags == [.init(key: "unified.simple.notice.privateTag", title: "私账", blocking: true)])
        #expect(try f.todos().isEmpty && f.io.trace.filter { $0 == "save" }.isEmpty && f.files().isEmpty)
    }

    @Test func originalSignatureStillReadsTheGivenPasteboard() throws {
        let store = try TaskCaptureFixture()
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-tm6-board-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let board = NSPasteboard(name: .init("areachain.tm6.capture.\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("私有剪贴板 #测试", forType: .string)
        #expect(ClipboardCapture.ingest(container: store.container, pasteboard: board, storage: AttachmentStore(root: root)))
        let todo = try #require(try ModelContext(store.container).fetch(FetchDescriptor<TodoItem>()).first)
        #expect(todo.title == "私有剪贴板 #测试" && !todo.tagIDs.isEmpty && board.string(forType: .string) == "私有剪贴板 #测试")
    }

    @Test func previewDoesNotReadAndSubmitReadsOnceTextFirst() throws {
        let f = try Fixture()
        f.contents = .init(text: "  会议纪要 #工作 !p1 @09:00  ", image: Self.image())
        try f.start()
        let preview = try f.prepare()
        #expect(f.reads == 0 && preview.dayKey == TaskSimpleFixture.today && preview.stampsSource)
        #expect(try f.todos().isEmpty && f.io.trace.isEmpty)
        let facts = try f.submit(preview)
        #expect(f.reads == 1 && facts.state == .saved && facts.kind == .text && !facts.attachedImage && facts.tagCount == 1)
        let todo = try #require(try f.todos().first)
        // 保留原文、只解析普通标签：不解析时间与优先级；有文字时不挂图。
        #expect(todo.id == preview.todoID && todo.title == "会议纪要 #工作 !p1 @09:00" && todo.remindMinutes == nil)
        #expect(!todo.isImportant && !todo.isUrgent && todo.sourceBundleID == "qa.source.app" && todo.dayKey == TaskSimpleFixture.today)
        let links = try ModelContext(f.io.container).fetch(FetchDescriptor<AttachmentItem>())
        #expect(f.files().isEmpty && links.isEmpty)
        #expect(f.io.trace.filter { $0 == "save" }.count == 1 && f.io.trace.filter { $0 == "ui" }.count == 1 && f.refreshes == [true])
        #expect(throws: ClipboardCaptureCommandIssue.alreadySubmitted) { try f.submit(preview) }
        let after = try f.todos()
        #expect(f.reads == 1 && after.count == 1)
    }

    @Test func imageOnlyAttachesAndEmptyClipboardWritesNothing() throws {
        let f = try Fixture()
        f.contents = .init(text: nil, image: Self.image())
        try f.start()
        let facts = try f.submit(f.prepare())
        #expect(facts.state == .saved && facts.kind == .image && facts.attachedImage)
        let todo = try #require(try f.todos().first)
        let links = try ModelContext(f.io.container).fetch(FetchDescriptor<AttachmentItem>())
        #expect(todo.title == L10n.string("capture.image", locale: Locale(identifier: "zh-Hans")) && links.count == 1)
        #expect(links.first?.ownerID == todo.id && f.files().contains { !$0.hasPrefix(".") })
        let empty = try Fixture()
        try empty.start()
        let none = try empty.submit(empty.prepare())
        let nothing = try empty.todos()
        #expect(none.state == .empty && empty.reads == 1 && nothing.isEmpty && empty.io.trace.isEmpty)
    }

    /// 写附件文件后失败：整体回滚、不发布，刚写的文件被清掉，不留孤儿。
    @Test func attachmentWriteFailureLeavesNoOrphanFile() throws {
        let f = try Fixture()
        f.storage = FailingAttachmentStorage(root: f.root)
        f.contents = .init(text: nil, image: Self.image())
        try f.start()
        let facts = try f.submit(f.prepare())
        let todos = try f.todos()
        #expect(facts.state == .notSubmitted && !facts.attachedImage && todos.isEmpty)
        #expect(f.files().filter { !$0.hasPrefix(".") }.isEmpty && !f.io.trace.contains("save") && f.refreshes.isEmpty)
    }

    @Test(arguments: [TaskCreateCommandIO.SaveMode.throwBefore, .throwAfter])
    func unknownResultBlocksRetryUntilVerified(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try Fixture()
        f.saveMode = mode
        f.contents = .init(text: nil, image: Self.image())
        try f.start()
        let preview = try f.prepare()
        let facts = try f.submit(preview)
        #expect(facts.state == .unknown && f.adapter.unresolved[preview.todoID] == preview.attachmentID)
        // 结果未知时文件可能已被引用，先不删；核对前不能再提交新的捕获。
        #expect(f.files().contains(preview.attachmentID.uuidString))
        #expect(throws: ClipboardCaptureCommandIssue.verificationRequired) { try f.submit(f.prepare()) }
        let outcome = try f.adapter.verifyUnknown(preview.todoID, expecting: f.handoff.owned().lease)
        #expect(outcome == (mode == .throwAfter ? .present : .absent) && f.adapter.unresolved.isEmpty)
        #expect(f.files().contains(preview.attachmentID.uuidString) == (mode == .throwAfter))
        let todos = try f.todos()
        #expect(todos.count == (mode == .throwAfter ? 1 : 0) && f.refreshes.isEmpty && f.reads == 1)
    }

    @Test func unassembledOrInvalidDraftsAreRejected() throws {
        let f = try Fixture()
        let bare = ClipboardCaptureCommandAdapter(coordinator: f.handoff.coordinator)
        #expect(!bare.supports(.init(rawValue: "capture.clipboard")) && f.adapter.supports(.init(rawValue: "capture.clipboard")))
        #expect(!f.adapter.supports(.init(rawValue: "todo.copy")))
        try f.start(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "capture.clipboard"),
                          targets: .init(.single, objects: [.init(type: .todo, id: UUID())])))
        #expect(throws: ClipboardCaptureCommandIssue.unsupportedPlan) { try f.prepare() }
        #expect(f.reads == 0)
    }
}
