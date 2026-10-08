import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

enum SearchMultilineConsumer: String, CaseIterable {
    case workspace, menu, clipboard, tags, diary, capture, form
    static let searches: [Self] = [.workspace, .menu, .clipboard, .tags, .diary]
    static let ordinarySearches: [Self] = [.workspace, .menu, .tags, .diary]
}

@MainActor @Observable
final class SearchMultilineDraft {
    struct Submission {
        let kind: String
        let before: Int
        let after: Int
        let uptime: TimeInterval
        let wallTime: TimeInterval
    }
    var didSubmit: ((Submission) -> Void)?
    var text = ""
    var focused = false
    var commits = 0
    var diaryCommits = 0
    var tokenRemovals = 0
    var committedIDs: [UUID] = []
    var committedOptions: [(plain: Bool, paste: Bool)] = []
    var allowsDiaryShortcut = true
    var showsCapture = true
    var showsSecondary = false
    var secondaryText = ""

    // 原合成回调的唯一累加处；观察者只接收事实，不决定提交或清理草稿。
    func submit(_ kind: String) {
        let before = kind == "diary" ? diaryCommits : commits
        if kind == "diary" { diaryCommits += 1 }
        else { commits += 1 }
        didSubmit?(Submission(kind: kind, before: before, after: before + 1,
                              uptime: ProcessInfo.processInfo.systemUptime, wallTime: Date().timeIntervalSince1970))
    }
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
    let locale: String
    let window: NSWindow

    init(_ kind: SearchMultilineConsumer, locale: String = "en", scheme: ColorScheme = .light,
         size: NSSize = NSSize(width: 700, height: 600), commitsOnClick: Bool = false,
         platform: ControlsPlatformAcceptance? = nil) throws {
        self.kind = kind
        self.locale = locale
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
            draft: draft, session: session, entries: entries, vault: vault, commitsOnClick: commitsOnClick,
            platform: platform), locale: locale, scheme: scheme, size: size,
            suppliedWindow: platform == nil ? nil : ControlsEvidenceWindow())
    }

    func cleanup() {
        SystemPageHost.release(window)
        base.cleanup()
    }

    func prepare() async throws -> NSTextField {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(observedField)
        _ = try await FormInputTestSupport.editor(field, in: window)
        return field
    }

    var observedField: NSTextField? {
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
        let placeholder = kind == .form ? key : L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        let matches = fields.filter { $0.placeholderString == placeholder }
        return matches.count == 1 ? matches.first : nil
    }

    /// 仅输出预定合成值的相等布尔和数值；不保存任意输入或其摘要，也不请求编辑器/焦点。
    func inputEvidence() -> [String: Any] {
        let field = observedField
        let query = (field?.delegate as? DaybookTextField.Coordinator)?.parent.text
            ?? (kind == .capture ? draft.text : nil)
        let editor = field?.currentEditor() as? NSTextView
        var values: [String: Any] = ["consumer": kind.rawValue, "fieldExists": field != nil,
            "queryAvailable": query != nil, "editorExists": editor != nil,
            "editorIsFirstResponder": editor != nil && window.firstResponder === editor,
            "todoCommits": draft.commits, "diaryCommits": draft.diaryCommits]
        if let query {
            for (name, expected) in ["LF": "甲\n乙", "Space": "甲 乙", "LiteralEscape": #"甲\n乙"#,
                "Empty": "", "TypedX": "x", "MiddleInitial": "头🧪尾", "MiddleSpace": "头🧪甲 乙尾",
                "MiddleLF": "头🧪甲\n乙尾", "MiddleTypedX": "头🧪x尾"] {
                values["queryIs" + name] = query == expected
            }
            values["queryUTF16Length"] = query.utf16.count
            values["fieldMatchesQuery"] = field?.stringValue == query
            if let editor { values["editorMatchesQuery"] = editor.string == query }
            values.merge(resultEvidence(query: query)) { _, new in new }
        }
        if let editor {
            values["editorUTF16Length"] = editor.string.utf16.count
            values["selectionLocation"] = editor.selectedRange().location
            values["selectionLength"] = editor.selectedRange().length
            values["marked"] = editor.hasMarkedText()
        }
        return values
    }

    private func resultEvidence(query: String) -> [String: Any] {
        if kind == .clipboard {
            let expected: Set<String>?
            switch query {
            case "甲\n乙": expected = ["甲\n乙 CLIP_LF"]
            case #"甲\n乙"#: expected = session.searchMode == .regex ? ["甲\n乙 CLIP_LF"] : [#"甲\n乙 CLIP_ESCAPE"#]
            case "": expected = Set(session.items.map(\.plainText))
            case "x", "头🧪尾", "头🧪甲\n乙尾", "头🧪x尾": expected = []
            default: expected = nil
            }
            var values: [String: Any] = ["clipboardMode": session.searchMode.rawValue]
            if let expected { values["resultsMatchExpected"] = Set(session.visibleItems.map(\.plainText)) == expected }
            return values
        }
        guard SearchMultilineConsumer.ordinarySearches.contains(kind) else { return [:] }
        let labels = FormInputTestSupport.labels(in: window).joined(separator: "\n")
        let prefix = kind == .tags ? "TAG" : (kind == .diary ? "DIARY" : "TASK")
        let space = labels.contains("\(prefix)_SPACE")
        let slash = labels.contains("\(prefix)_SLASH")
        var values: [String: Any] = ["resultHasSpace": space, "resultHasSlash": slash]
        if query == "甲 乙" { values["resultsMatchExpected"] = space && (slash == (kind != .tags)) }
        if ["x", "头🧪尾", "头🧪甲 乙尾", "头🧪x尾"].contains(query) { values["resultsMatchExpected"] = !space && !slash }
        return values
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
    var commitsOnClick = false
    var platform: ControlsPlatformAcceptance?

    var body: some View {
        VStack {
            if let platform { ControlsPlatformFeedback(session: platform) }
            if platform != nil && kind == .clipboard {
                Picker("匹配模式 / Mode", selection: $session.searchMode) {
                    Text("mixed").tag(ClipboardSearchMode.mixed)
                    Text("exact").tag(ClipboardSearchMode.exact)
                    Text("regex").tag(ClipboardSearchMode.regex)
                }
            }
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
                ClipboardHistoryBrowser(session: session, showsFooter: true, commitsOnClick: commitsOnClick,
                                        onCommit: { id, plain, paste in
                    draft.submit("clipboard")
                    draft.committedIDs.append(id)
                    draft.committedOptions.append((plain, paste))
                })
            case .tags: TagManagementPage()
            case .diary:
                DiaryPage(todayKey: "2026-10-05", entries: entries, options: DiaryPageOptions(showsComposer: false, vault: vault))
            case .capture:
                if draft.showsCapture {
                    CaptureField(text: $draft.text, focus: $draft.focused,
                                 onTodo: { draft.submit("todo") }, onDiary: { draft.submit("diary") },
                                 allowsDiaryShortcut: draft.allowsDiaryShortcut)
                }
                if draft.showsSecondary {
                    DaybookFormTextField(verbatim: "SYNTHETIC_SECONDARY", text: $draft.secondaryText)
                }
            case .form: DaybookFormTextField(verbatim: "SYNTHETIC_FORM", text: $draft.text)
            }
        }
        .padding(16)
    }
}
