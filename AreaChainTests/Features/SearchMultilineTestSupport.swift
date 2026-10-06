import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

enum SearchMultilineConsumer: String, CaseIterable {
    case workspace, menu, clipboard, tags, diary, capture, form
    static let searches: [Self] = [.workspace, .menu, .clipboard, .tags, .diary]
}

@MainActor @Observable
final class SearchMultilineDraft {
    var text = ""
    var focused = false
    var commits = 0
    var diaryCommits = 0
    var tokenRemovals = 0
    var committedIDs: [UUID] = []
}

/// 沿原剪贴板隔离夹具和 SystemPageHost；只装配生产控件，不复制搜索实现。
@MainActor
final class SearchMultilineFixture {
    let base: ClipboardOptionsFixture
    let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
    let toolbar = MenuBarToolbarState()
    let draft = SearchMultilineDraft()
    let session: ClipboardHistorySession
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let entries: [DiaryEntry]
    let kind: SearchMultilineConsumer
    let window: NSWindow

    init(_ kind: SearchMultilineConsumer) throws {
        self.kind = kind
        let base = try ClipboardOptionsFixture()
        self.base = base
        let context = base.native.container.mainContext
        entries = ["甲 乙 DIARY_SPACE", "甲 // 乙 DIARY_SLASH"].map { DiaryEntry(text: $0, dayKey: "2026-10-05") }
        for entry in entries { context.insert(entry) }
        for (index, name) in ["工作", "甲 乙 TAG_SPACE", "甲 // 乙 TAG_SLASH"].enumerated() {
            context.insert(TagItem(name: name, sortOrder: index))
        }
        for title in ["甲 乙 TASK_SPACE", "甲 // 乙 TASK_SLASH"] {
            context.insert(TodoItem(title: title, dayKey: "2026-10-05"))
        }
        try context.save()
        let records = ["甲\n乙 CLIP_LF", "甲 乙 CLIP_SPACE", "甲 // 乙 CLIP_SLASH", #"甲\n乙 CLIP_ESCAPE"#].map {
            ClipboardHistoryRecord(id: UUID(), copiedAt: .now, pinnedAt: nil, sourceBundleID: "",
                plainText: $0, html: nil, rtf: nil, imageFile: nil, contentHash: UUID().uuidString)
        }
        try ClipboardHistoryStore(root: base.root).save(records)
        session = base.session()
        window = base.native.window(SearchMultilineHost(kind: kind, navigation: navigation, toolbar: toolbar,
            draft: draft, session: session, entries: entries, vault: vault), size: NSSize(width: 700, height: 600))
    }

    func cleanup() {
        SystemPageHost.release(window)
        base.cleanup()
    }

    func prepare() async throws -> NSTextField {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let fields = FormInputTestSupport.fields(in: window)
        // 手记卡片正文不是搜索；只通过原本地化 placeholder 唯一定位。
        let key: String
        switch kind {
        case .workspace: key = "workspace.search.placeholder"
        case .menu: key = "footer.search.placeholder.short"
        case .clipboard: key = "clipboard.search"
        case .tags: key = "tags.search.placeholder"
        case .diary: key = "diary.search.placeholder"
        case .capture: key = "capture.placeholder.today"
        case .form: key = "SYNTHETIC_FORM"
        }
        let placeholder = kind == .form ? key : L10n.string(String.LocalizationValue(key), locale: Locale(identifier: "en"))
        let matches = fields.filter { $0.placeholderString == placeholder }
        try #require(matches.count == 1)
        let field = try #require(matches.first)
        _ = try await FormInputTestSupport.editor(field, in: window)
        return field
    }

    func assertResults(space: Bool, slash: Bool) {
        let labels = FormInputTestSupport.labels(in: window).joined(separator: "\n")
        let prefix: String
        switch kind {
        case .workspace, .menu: prefix = "TASK"
        case .diary: prefix = "DIARY"
        case .tags: prefix = "TAG"
        case .clipboard: prefix = "CLIP"
        default: return
        }
        #expect(labels.contains("\(prefix)_SPACE") == space)
        #expect(labels.contains("\(prefix)_SLASH") == slash)
    }
}

@MainActor
private struct SearchMultilineHost: View {
    let kind: SearchMultilineConsumer
    @Bindable var navigation: WorkspaceNavigation
    @Bindable var toolbar: MenuBarToolbarState
    @Bindable var draft: SearchMultilineDraft
    @Bindable var session: ClipboardHistorySession
    let entries: [DiaryEntry]
    let vault: PrivacyVault

    var body: some View {
        VStack {
            switch kind {
            case .workspace:
                WorkspaceHeaderSearchCapsule(navigation: navigation, tagNames: ["工作"])
                WorkspaceGlobalSearchView(navigation: navigation, query: navigation.searchQuery)
            case .menu:
                MenuBarSearchField(toolbar: toolbar, availableTags: ["工作"], tokens: [
                    SearchFilterToken(id: "synthetic", title: "SYNTHETIC_TOKEN", onRemove: { draft.tokenRemovals += 1 })
                ])
                MenuBarSearchResults(query: toolbar.searchText, filter: BoardFilter(), toolbar: toolbar,
                                     onClearSearch: { toolbar.clearSearch() }, onClearFilter: {})
            case .clipboard:
                ClipboardHistoryBrowser(session: session, showsFooter: true, commitsOnClick: false,
                                        onCommit: { id, _, _ in draft.commits += 1; draft.committedIDs.append(id) })
            case .tags: TagManagementPage()
            case .diary:
                DiaryPage(todayKey: "2026-10-05", entries: entries, options: DiaryPageOptions(showsComposer: false, vault: vault))
            case .capture:
                CaptureField(text: $draft.text, focus: $draft.focused,
                             onTodo: { draft.commits += 1 }, onDiary: { draft.diaryCommits += 1 })
            case .form: DaybookFormTextField(verbatim: "SYNTHETIC_FORM", text: $draft.text)
            }
        }
        .padding(16)
    }
}
