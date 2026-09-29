import AppKit
import Foundation

enum ClipboardPasteResult: Equatable {
    case copied
    case pasted
    case needsAccessibility
    case empty
    case saveFailed
}

/// 剪贴板历史的唯一状态。页面和浮窗都读这里，不各自存一份。
@MainActor
@Observable
final class ClipboardHistorySession {
    static let shared: ClipboardHistorySession = {
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if testing {
            let root = FileManager.default.temporaryDirectory
                .appending(path: "areachain-clipboard-\(UUID().uuidString)", directoryHint: .isDirectory)
            let defaults = UserDefaults(suiteName: "areachain.clipboard.preview.\(UUID().uuidString)") ?? .standard
            return ClipboardHistorySession(store: ClipboardHistoryStore(root: root), defaults: defaults, pasteboard: nil)
        }
        return ClipboardHistorySession(store: ClipboardHistoryStore(), defaults: .standard, pasteboard: .general)
    }()

    private let store: ClipboardHistoryStore
    private let defaults: UserDefaults
    private let pasteboard: NSPasteboard?
    private let gate: ClipboardHistoryPasteGate
    private var monitor: ClipboardHistoryMonitor?
    private var didStart = false

    private(set) var items: [ClipboardHistoryRecord] = []
    var query = ""
    var searchMode: ClipboardSearchMode = .mixed
    var recording = true
    var ignoreNext = false
    var limit = ClipboardHistoryRules.defaultLimit
    var interval = ClipboardHistoryRules.defaultInterval
    var ignoreUniversal = false
    var panelAnchor: ClipboardPanelAnchor = .cursor
    var panelStaysOnTop = true
    var clickAction: ClipboardClickAction = .copy
    var plainByDefault = false
    var playSound = false
    var ignoredApps: [String] = []
    var extraTypes: [String] = []
    var patterns: [String] = []
    var selectedID: UUID?
    var noticeKey: String?
    var pageOwnsKeys = false
    var clipboardFieldFocused = false

    init(
        store: ClipboardHistoryStore,
        defaults: UserDefaults,
        pasteboard: NSPasteboard?,
        gate: ClipboardHistoryPasteGate = .live
    ) {
        self.store = store
        self.defaults = defaults
        self.pasteboard = pasteboard
        self.gate = gate
        loadPreferences()
        items = store.load()
    }

    var visibleItems: [ClipboardHistoryRecord] {
        ClipboardHistoryRules.filtered(items, query: query, mode: searchMode)
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        guard let pasteboard else { return }
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: { [weak self] in
            self?.interval ?? ClipboardHistoryRules.defaultInterval
        }, onChange: { [weak self] in
            self?.ingestCurrentPasteboard()
        })
        self.monitor = monitor
        monitor.start()
    }

    func imageData(for record: ClipboardHistoryRecord) -> Data? {
        guard let name = record.imageFile else { return nil }
        return store.imageData(named: name)
    }

    func togglePin(_ id: UUID) {
        let next = items.contains(where: { $0.id == id && $0.isPinned })
            ? ClipboardHistoryRules.unpin(items, id: id)
            : ClipboardHistoryRules.pin(items, id: id, at: .now)
        commit(next)
    }

    func delete(_ id: UUID) {
        if selectedID == id { selectedID = nil }
        commit(ClipboardHistoryRules.removing(items, id: id))
    }

    func clear(includingPinned: Bool) {
        selectedID = nil
        commit(ClipboardHistoryRules.clearing(items, includingPinned: includingPinned))
    }

    func ignoreApp(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !ignoredApps.contains(trimmed) else { return }
        ignoredApps.append(trimmed)
        savePreferences()
    }

    func removeIgnoredApp(_ bundleID: String) {
        ignoredApps.removeAll { $0 == bundleID }
        savePreferences()
    }

    func addPattern(_ pattern: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ClipboardHistoryRules.isValidPattern(trimmed), !patterns.contains(trimmed) else { return false }
        patterns.append(trimmed)
        savePreferences()
        return true
    }

    func removePattern(_ pattern: String) {
        patterns.removeAll { $0 == pattern }
        savePreferences()
    }

    func addType(_ type: String) -> Bool {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !extraTypes.contains(trimmed), !ClipboardHistoryRules.sealedTypes.contains(trimmed) else {
            return false
        }
        extraTypes.append(trimmed)
        savePreferences()
        return true
    }

    func removeType(_ type: String) {
        extraTypes.removeAll { $0 == type }
        savePreferences()
    }

    func setRecording(_ enabled: Bool) {
        recording = enabled
        savePreferences()
    }

    func setLimit(_ value: Int) {
        limit = ClipboardHistoryRules.clampLimit(value)
        commit(ClipboardHistoryRules.trimming(items, limit: limit))
        savePreferences()
    }

    func setInterval(_ value: TimeInterval) {
        interval = ClipboardHistoryRules.clampInterval(value)
        savePreferences()
        monitor?.reschedule()
    }

    func setSearchMode(_ mode: ClipboardSearchMode) {
        searchMode = mode
        savePreferences()
    }

    func setIgnoreUniversal(_ enabled: Bool) {
        ignoreUniversal = enabled
        savePreferences()
    }

    func setPanelAnchor(_ anchor: ClipboardPanelAnchor) {
        panelAnchor = anchor
        savePreferences()
    }

    func setPanelStaysOnTop(_ enabled: Bool) {
        panelStaysOnTop = enabled
        savePreferences()
    }

    func setClickAction(_ action: ClipboardClickAction) {
        clickAction = action
        savePreferences()
    }

    func setPlainByDefault(_ enabled: Bool) {
        plainByDefault = enabled
        savePreferences()
    }

    func setPlaySound(_ enabled: Bool) {
        playSound = enabled
        savePreferences()
    }

    func armIgnoreNext() {
        ignoreNext = true
        noticeKey = "clipboard.ignoreNext.done"
    }

    func moveSelection(by delta: Int) {
        let rows = visibleItems
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex(where: { $0.id == selectedID }) ?? (delta > 0 ? -1 : 0)
        let next = min(max(current + delta, 0), rows.count - 1)
        selectedID = rows[next].id
    }

    func item(atQuickIndex index: Int) -> ClipboardHistoryRecord? {
        let rows = visibleItems
        guard index >= 1, index <= rows.count else { return nil }
        return rows[index - 1]
    }

    func selectedOrFirst() -> ClipboardHistoryRecord? {
        if let selectedID, let match = visibleItems.first(where: { $0.id == selectedID }) {
            return match
        }
        return visibleItems.first
    }

    func stage(_ id: UUID, plainOnly: Bool) -> ClipboardPasteResult {
        guard let record = items.first(where: { $0.id == id }) else { return .empty }
        let board = pasteboard ?? .general
        let image = imageData(for: record)
        guard ClipboardHistoryWriter.write(record, image: image, plainOnly: plainOnly, to: board) else { return .empty }
        monitor?.acknowledge(board.changeCount)
        return .copied
    }

    func allowKeystroke(prompt: Bool) -> Bool {
        if gate.isTrusted() { return true }
        if prompt { gate.prompt() }
        return gate.isTrusted()
    }

    func sendPasteKeystroke() {
        gate.sendCommandV()
    }

    func ingestCurrentPasteboard() {
        guard let pasteboard else { return }
        ingest(ClipboardPasteboardReader.draft(
            from: pasteboard,
            frontBundle: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        ))
    }

    func ingest(_ draft: ClipboardHistoryDraft) {
        guard recording else { return }
        guard var record = ClipboardHistoryRules.record(
            from: draft,
            ignoredApps: Set(ignoredApps),
            extraTypes: Set(extraTypes),
            patterns: patterns,
            ignoreUniversal: ignoreUniversal
        ) else { return }
        if ignoreNext {
            ignoreNext = false
            return
        }
        if let existing = items.first(where: { $0.contentHash == record.contentHash }) {
            record.id = existing.id
            record.pinnedAt = existing.pinnedAt
            record.imageFile = existing.imageFile
        }
        if record.imageFile == nil, let png = draft.png, png.count <= ClipboardHistoryRules.maximumPayloadBytes {
            if let name = try? store.writeImage(png, id: record.id) {
                record.imageFile = name
            }
        }
        let next = ClipboardHistoryRules.merging(items, new: record, limit: limit)
        if commit(next), playSound {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
    }

    @discardableResult
    private func commit(_ next: [ClipboardHistoryRecord]) -> Bool {
        do {
            try store.save(next)
            items = next
            store.pruneImages(keeping: Set(next.compactMap(\.imageFile)))
            noticeKey = nil
            return true
        } catch {
            noticeKey = "clipboard.save.failed"
            return false
        }
    }

    private func loadPreferences() {
        if defaults.object(forKey: Keys.recording) != nil {
            recording = defaults.bool(forKey: Keys.recording)
        }
        if defaults.object(forKey: Keys.limit) != nil {
            limit = ClipboardHistoryRules.clampLimit(defaults.integer(forKey: Keys.limit))
        }
        if defaults.object(forKey: Keys.interval) != nil {
            interval = ClipboardHistoryRules.clampInterval(defaults.double(forKey: Keys.interval))
        }
        if let raw = defaults.string(forKey: Keys.searchMode), let mode = ClipboardSearchMode(rawValue: raw) {
            searchMode = mode
        }
        ignoreUniversal = defaults.bool(forKey: Keys.ignoreUniversal)
        if let raw = defaults.string(forKey: Keys.panelAnchor), let anchor = ClipboardPanelAnchor(rawValue: raw) {
            panelAnchor = anchor
        }
        if defaults.object(forKey: Keys.panelStaysOnTop) != nil {
            panelStaysOnTop = defaults.bool(forKey: Keys.panelStaysOnTop)
        }
        if let raw = defaults.string(forKey: Keys.clickAction), let action = ClipboardClickAction(rawValue: raw) {
            clickAction = action
        }
        plainByDefault = defaults.bool(forKey: Keys.plainByDefault)
        playSound = defaults.bool(forKey: Keys.playSound)
        ignoredApps = defaults.stringArray(forKey: Keys.ignoredApps) ?? []
        extraTypes = defaults.stringArray(forKey: Keys.extraTypes) ?? []
        patterns = defaults.stringArray(forKey: Keys.patterns) ?? []
    }

    private func savePreferences() {
        defaults.set(recording, forKey: Keys.recording)
        defaults.set(limit, forKey: Keys.limit)
        defaults.set(interval, forKey: Keys.interval)
        defaults.set(searchMode.rawValue, forKey: Keys.searchMode)
        defaults.set(ignoreUniversal, forKey: Keys.ignoreUniversal)
        defaults.set(panelAnchor.rawValue, forKey: Keys.panelAnchor)
        defaults.set(panelStaysOnTop, forKey: Keys.panelStaysOnTop)
        defaults.set(clickAction.rawValue, forKey: Keys.clickAction)
        defaults.set(plainByDefault, forKey: Keys.plainByDefault)
        defaults.set(playSound, forKey: Keys.playSound)
        defaults.set(ignoredApps, forKey: Keys.ignoredApps)
        defaults.set(extraTypes, forKey: Keys.extraTypes)
        defaults.set(patterns, forKey: Keys.patterns)
    }

    private enum Keys {
        static let recording = "areachain.clipboard.recording"
        static let limit = "areachain.clipboard.limit"
        static let interval = "areachain.clipboard.interval"
        static let searchMode = "areachain.clipboard.searchMode"
        static let ignoreUniversal = "areachain.clipboard.ignoreUniversal"
        static let panelAnchor = "areachain.clipboard.panelAnchor"
        static let panelStaysOnTop = "areachain.clipboard.panelStaysOnTop"
        static let clickAction = "areachain.clipboard.clickAction"
        static let plainByDefault = "areachain.clipboard.plainByDefault"
        static let playSound = "areachain.clipboard.playSound"
        static let ignoredApps = "areachain.clipboard.ignoredApps"
        static let extraTypes = "areachain.clipboard.extraTypes"
        static let patterns = "areachain.clipboard.patterns"
    }
}
