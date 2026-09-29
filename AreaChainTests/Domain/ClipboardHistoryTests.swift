import AppKit
import Foundation
import Testing
@testable import AreaChain

struct ClipboardHistoryRulesTests {
    private func draft(
        text: String = "hello",
        types: Set<String> = ["public.utf8-plain-text"],
        bundle: String = "com.example.Editor",
        png: Data? = nil
    ) -> ClipboardHistoryDraft {
        ClipboardHistoryDraft(
            plainText: text,
            html: nil,
            rtf: nil,
            png: png,
            types: types,
            sourceBundleID: bundle,
            copiedAt: Date(timeIntervalSince1970: 10)
        )
    }

    @Test func concealedPasswordCopiesAreDropped() {
        let types: Set<String> = ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]
        let record = ClipboardHistoryRules.record(
            from: draft(text: "secret", types: types),
            ignoredApps: [],
            extraTypes: [],
            patterns: [],
            ignoreUniversal: false
        )
        #expect(record == nil)
    }

    @Test func ownWritesAndPasswordManagersAreDropped() {
        for type in [ClipboardHistoryRules.markerType, "com.agilebits.onepassword", "net.antelle.keeweb"] {
            let record = ClipboardHistoryRules.record(
                from: draft(types: ["public.utf8-plain-text", type]),
                ignoredApps: [],
                extraTypes: [],
                patterns: [],
                ignoreUniversal: false
            )
            #expect(record == nil)
        }
    }

    @Test func ignoredAppPatternAndUniversalClipboard() {
        #expect(ClipboardHistoryRules.record(
            from: draft(),
            ignoredApps: ["com.example.Editor"],
            extraTypes: [],
            patterns: [],
            ignoreUniversal: false
        ) == nil)
        #expect(ClipboardHistoryRules.record(
            from: draft(text: "token sk-123"),
            ignoredApps: [],
            extraTypes: [],
            patterns: ["sk-\\d+"],
            ignoreUniversal: false
        ) == nil)
        let remote = draft(types: ["public.utf8-plain-text", ClipboardHistoryRules.universalClipboardType])
        #expect(ClipboardHistoryRules.record(
            from: remote, ignoredApps: [], extraTypes: [], patterns: [], ignoreUniversal: false
        ) != nil)
        #expect(ClipboardHistoryRules.record(
            from: remote, ignoredApps: [], extraTypes: [], patterns: [], ignoreUniversal: true
        ) == nil)
    }

    @Test func pinsStayWhileUnpinnedItemsTrimToTheLimit() {
        let pinned = record("keep", at: 1, pinned: Date(timeIntervalSince1970: 1))
        let older = (2...10).map { record("old-\($0)", at: TimeInterval($0)) }
        let newer = (11...30).map { record("new-\($0)", at: TimeInterval($0)) }
        let trimmed = ClipboardHistoryRules.trimming([pinned] + older + newer, limit: 20)
        #expect(trimmed.contains(where: { $0.plainText == "keep" && $0.isPinned }))
        #expect(trimmed.filter { !$0.isPinned }.count == 20)
        #expect(!trimmed.contains(where: { $0.plainText == "old-2" }))
        #expect(trimmed.contains(where: { $0.plainText == "new-30" }))
    }

    @Test func duplicateCopyRefreshesTheExistingItemAndKeepsThePin() {
        let first = record("same", at: 5, hash: "h", pinned: Date(timeIntervalSince1970: 1))
        var again = record("same", at: 9, hash: "h")
        again.id = UUID()
        let merged = ClipboardHistoryRules.merging([first], new: again, limit: 20)
        #expect(merged.count == 1)
        #expect(merged[0].id == first.id)
        #expect(merged[0].isPinned)
        #expect(merged[0].copiedAt == again.copiedAt)
    }

    @Test func searchModes() {
        let items = [record("Alpha", at: 1), record("beta", at: 2)]
        #expect(ClipboardHistoryRules.filtered(items, query: "alp", mode: .mixed).count == 1)
        #expect(ClipboardHistoryRules.filtered([record("catalog", at: 3)], query: "cta", mode: .mixed).count == 1)
        #expect(ClipboardHistoryRules.filtered([record("catalog", at: 3)], query: "cta", mode: .exact).isEmpty)
        #expect(ClipboardHistoryRules.highlightRanges(in: "catalog", needle: "cta", mode: .mixed).map { String("catalog"[$0]) } == ["c", "t", "a"])
        #expect(ClipboardHistoryRules.filtered(items, query: "alp", mode: .exact).isEmpty)
        #expect(ClipboardHistoryRules.filtered(items, query: "Alpha", mode: .exact).count == 1)
        #expect(ClipboardHistoryRules.filtered(items, query: "^b", mode: .regex).map(\.plainText) == ["beta"])
        #expect(ClipboardHistoryRules.filtered(items, query: "(", mode: .regex).isEmpty)
    }

    @Test func pinLettersStayPutAndReturnAfterUnpin() {
        let first = record("one", at: 1)
        let second = record("two", at: 2)
        let once = ClipboardHistoryRules.pin([first, second], id: first.id, at: Date(timeIntervalSince1970: 3))
        let twice = ClipboardHistoryRules.pin(once, id: second.id, at: Date(timeIntervalSince1970: 4))
        #expect(twice.first { $0.id == first.id }?.pinKey == "a")
        #expect(twice.first { $0.id == second.id }?.pinKey == "b")
        let released = ClipboardHistoryRules.unpin(twice, id: first.id)
        #expect(released.first { $0.id == first.id }?.pinKey == nil)
        let reused = ClipboardHistoryRules.pin(released, id: first.id, at: Date(timeIntervalSince1970: 5))
        #expect(reused.first { $0.id == first.id }?.pinKey == "a")
        let merged = ClipboardHistoryRules.merging(reused, new: record("one", at: 9), limit: 20)
        #expect(merged.first { $0.plainText == "one" }?.pinKey == "a")
    }

    @Test func clearingKeepsPinsUnlessAsked() {
        let pinned = record("pin", at: 1, pinned: .now)
        let loose = record("loose", at: 2)
        #expect(ClipboardHistoryRules.clearing([pinned, loose], includingPinned: false) == [pinned])
        #expect(ClipboardHistoryRules.clearing([pinned, loose], includingPinned: true).isEmpty)
    }

    @Test func historyHotKeyStartsUnsetAndYieldsToAnEarlierGlobalHotKey() {
        let resolved = ShortcutCatalog.resolve(stored: [:])
        #expect(resolved[.clipboardHistory]?.chord.isUnset == true)
        #expect(resolved[.clipboardHistory]?.isArmed == false)
        let chord = ShortcutChord(
            keyCode: ShortcutKey.c,
            modifiers: ShortcutModifier.command | ShortcutModifier.shift
        )
        let clash = ShortcutCatalog.resolve(stored: [
            .pasteToday: chord,
            .clipboardHistory: chord
        ])
        #expect(clash[.pasteToday]?.isArmed == true)
        #expect(clash[.clipboardHistory]?.isArmed == false)
        #expect(clash[.clipboardHistory]?.chord == chord)
    }

    private func record(
        _ text: String,
        at time: TimeInterval,
        hash: String? = nil,
        pinned: Date? = nil
    ) -> ClipboardHistoryRecord {
        ClipboardHistoryRecord(
            id: UUID(),
            copiedAt: Date(timeIntervalSince1970: time),
            pinnedAt: pinned,
            sourceBundleID: "",
            plainText: text,
            html: nil,
            rtf: nil,
            imageFile: nil,
            contentHash: hash ?? text
        )
    }
}

@MainActor
struct ClipboardHistoryStoreTests {
    @Test func roundTripAndPlainPasteDoNotTouchTheGeneralPasteboard() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-clipboard-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ClipboardHistoryStore(root: root)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let imageName = try store.writeImage(png, id: UUID())
        let item = ClipboardHistoryRecord(
            id: UUID(),
            copiedAt: .now,
            pinnedAt: nil,
            sourceBundleID: "com.example",
            plainText: "saved",
            html: "<b>saved</b>",
            rtf: nil,
            imageFile: imageName,
            contentHash: "saved"
        )
        try store.save([item])
        let loaded = ClipboardHistoryStore(root: root).load()
        #expect(loaded == [item])
        #expect(store.imageData(named: imageName) == png)

        let board = NSPasteboard(name: .init("areachain.clipboard.tests.\(UUID().uuidString)"))
        defer { board.clearContents() }
        #expect(ClipboardHistoryWriter.write(item, image: png, plainOnly: true, to: board))
        #expect(board.string(forType: .string) == "saved")
        #expect(board.string(forType: .html) == nil)
        #expect(board.data(forType: ClipboardHistoryWriter.marker) != nil)
        #expect(board.data(forType: .png) == nil)
    }

    @Test func sessionSkipsTheNextRealCopyAndPauses() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-clipboard-session-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let name = "areachain.clipboard.session.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let session = ClipboardHistorySession(
            store: ClipboardHistoryStore(root: root),
            defaults: defaults,
            pasteboard: nil,
            gate: ClipboardHistoryPasteGate(isTrusted: { false }, prompt: {}, sendCommandV: {})
        )
        session.armIgnoreNext()
        session.ingest(ClipboardHistoryDraft(
            plainText: "skip-me",
            html: nil,
            rtf: nil,
            png: nil,
            types: ["public.utf8-plain-text"],
            sourceBundleID: "",
            copiedAt: .now
        ))
        #expect(session.items.isEmpty)
        #expect(!session.ignoreNext)
        session.ingest(ClipboardHistoryDraft(
            plainText: "keep-me",
            html: nil,
            rtf: nil,
            png: nil,
            types: ["public.utf8-plain-text"],
            sourceBundleID: "",
            copiedAt: .now
        ))
        #expect(session.items.map(\.plainText) == ["keep-me"])
        session.setRecording(false)
        session.ingest(ClipboardHistoryDraft(
            plainText: "later",
            html: nil,
            rtf: nil,
            png: nil,
            types: ["public.utf8-plain-text"],
            sourceBundleID: "",
            copiedAt: .now
        ))
        #expect(session.items.map(\.plainText) == ["keep-me"])
        session.setPanelAnchor(.center)
        session.setClickAction(.paste)
        session.setPlainByDefault(true)
        session.setInterval(0.4)
        let restored = ClipboardHistorySession(
            store: ClipboardHistoryStore(root: root),
            defaults: defaults,
            pasteboard: nil
        )
        #expect(restored.panelAnchor == .center)
        #expect(restored.clickAction == .paste)
        #expect(restored.plainByDefault)
        #expect(restored.interval == 0.4)
    }

    @Test func olderHistoryWithoutPinOrFilesStillLoads() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-clipboard-old-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let id = UUID()
        let json = """
        {"items":[{"id":"\(id.uuidString)","copiedAt":10,"sourceBundleID":"","plainText":"old","contentHash":"old"}]}
        """
        try Data(json.utf8).write(to: root.appending(path: "history.json"))
        let loaded = ClipboardHistoryStore(root: root).load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.plainText == "old")
        #expect(loaded.first?.pinKey == nil)
        #expect(loaded.first?.filePaths.isEmpty == true)
    }

    @Test func fileCopyPastesBackAsFileURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-clipboard-files-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "note.txt")
        try Data("hi".utf8).write(to: file)
        let item = ClipboardHistoryRecord(
            id: UUID(),
            copiedAt: .now,
            pinnedAt: nil,
            sourceBundleID: "",
            plainText: file.path,
            html: nil,
            rtf: nil,
            imageFile: nil,
            filePaths: [file.path],
            contentHash: "file"
        )
        let board = NSPasteboard(name: .init("areachain.clipboard.files.\(UUID().uuidString)"))
        defer { board.clearContents() }
        #expect(ClipboardHistoryWriter.write(item, image: nil, plainOnly: false, to: board))
        let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        #expect(urls?.map(\.standardizedFileURL.path) == [file.standardizedFileURL.path])
        #expect(board.data(forType: ClipboardHistoryWriter.marker) != nil)
        let draft = ClipboardPasteboardReader.draft(from: board, frontBundle: nil)
        #expect(draft.filePaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == [file.standardizedFileURL.path])

        #expect(ClipboardHistoryWriter.write(item, image: nil, plainOnly: true, to: board))
        let plainURLs = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        #expect(plainURLs?.isEmpty != false)
        #expect(board.string(forType: .string) == file.path)
    }
}
