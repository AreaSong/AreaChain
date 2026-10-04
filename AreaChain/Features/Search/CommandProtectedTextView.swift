import AppKit

/// C2B 隔离探针，没有生产装配。只接受能够在原生变更前完整预测的纯文本事务。
/// 系统 IME 暂存及外部 textStorage 写入不能提供同等保证，入口保持关闭。
@MainActor final class CommandProtectedTextView: DaybookAppKitTextView, CommandDraftNativeOwner, NSTextStorageDelegate {
    enum Issue: Equatable { case unavailable, rejected, compositionUnsupported, unsupportedMutation, reentrant }
    let parameter: CommandParameterID = .notes
    private let contentSession: CommandDraftContentSession
    private var localUndo = CommandNativeUndoManager()
    private(set) var access: CommandDraftContentAccess?
    private(set) var issue: Issue?
    private(set) var checkpointCount = 0
    private var installing = false
    private var accepting = false
    private var windowObservers: [NSObjectProtocol] = []
    #if DEBUG
    var testingAfterCheckpoint: (() -> Void)?
    var testingBeforeMarkedText: (() -> Void)?
    #endif

    init(session: CommandDraftContentSession) {
        contentSession = session
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 200), textContainer: container)
        isRichText = false
        importsGraphics = false
        allowsUndo = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        if #available(macOS 15.1, *) { writingToolsBehavior = .none }
        localUndo.groupsByEvent = false
        textStorage?.delegate = self
        isEditable = false
    }

    deinit { for observer in windowObservers { NotificationCenter.default.removeObserver(observer) } }

    required init?(coder: NSCoder) { nil }
    override var undoManager: UndoManager? { localUndo }

    /// 调用者只能传入一次真实显式恢复所得资格；解锁通知没有调用此方法的路径。
    func begin(using restored: CommandDraftContentAccess) throws {
        guard access == nil else { throw CommandDraftProtectionError.stale }
        do {
            try contentSession.attachNative(self, using: restored)
            access = restored
            localUndo = CommandNativeUndoManager()
            localUndo.groupsByEvent = false
            isEditable = true
            issue = nil
        } catch { clearProtectedContents(); issue = .unavailable; throw error }
    }

    func end() {
        // 旧控件不可撤销后来控件的资格。
        contentSession.detachNative(self)
        clearProtectedContents()
    }

    func clearProtectedContents() {
        access = nil
        isEditable = false
        installing = true
        defer { installing = false }
        super.unmarkText()
        super.string = ""
        super.setSelectedRange(NSRange(location: 0, length: 0))
        localUndo.revoke()
    }

    func installProtectedContents(_ state: CommandDraftEditingState) throws {
        guard contentSession.permitsNativeInstallation(self), state.parameter == parameter.rawValue else { throw CommandDraftProtectionError.invalidPayload }
        installing = true
        defer { installing = false }
        super.string = state.spelling
        guard contentSession.permitsNativeInstallation(self) else { throw CommandDraftProtectionError.stale }
        let selection = NSRange(location: state.selectionLocation, length: state.selectionLength)
        super.setSelectedRange(selection)
        guard textStorage != nil, super.string == state.spelling, selectedRange() == selection else {
            throw CommandDraftProtectionError.unavailable
        }
    }

    override var string: String {
        get { super.string }
        set {
            if installing { super.string = newValue }
            else { issue = .unsupportedMutation }
        }
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard let text = insertString as? String else { issue = .unsupportedMutation; return }
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange
        guard Range(range, in: super.string) != nil else { issue = .rejected; return }
        let candidate = (super.string as NSString).replacingCharacters(in: range, with: text)
        accept(candidate, selection: NSRange(location: range.location + text.utf16.count, length: 0))
    }

    override func deleteBackward(_ sender: Any?) {
        var range = selectedRange()
        if range.length == 0, range.location > 0 {
            range = (super.string as NSString).rangeOfComposedCharacterSequence(at: range.location - 1)
        }
        insertText("", replacementRange: range)
    }

    override func deleteForward(_ sender: Any?) {
        var range = selectedRange()
        if range.length == 0, range.location < super.string.utf16.count {
            range = (super.string as NSString).rangeOfComposedCharacterSequence(at: range.location)
        }
        insertText("", replacementRange: range)
    }

    override func insertNewline(_ sender: Any?) { insertText("\n", replacementRange: selectedRange()) }
    override func insertTab(_ sender: Any?) { insertText("\t", replacementRange: selectedRange()) }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, let text = pboard.string(forType: .string), let previous = access else { return false }
        insertText(text, replacementRange: selectedRange())
        return access != nil && access != previous
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool { false }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        #if DEBUG
        testingBeforeMarkedText?()
        #endif
        // 不调用 super：尚不能捕获系统候选窗/IME 自有暂存，拒绝不是一次已接受修订。
        issue = .compositionUnsupported
    }

    override func unmarkText() {
        if installing { super.unmarkText() }
        else { issue = .compositionUnsupported }
    }

    override func setSelectedRange(_ charRange: NSRange) {
        if installing { super.setSelectedRange(charRange) }
        else { accept(super.string, selection: charRange) }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        if installing { super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag); return }
        guard ranges.count == 1 else { issue = .unsupportedMutation; return }
        accept(super.string, selection: ranges[0].rangeValue)
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // 未经上述可预测入口的服务、拖放、系统替换等编辑不交由默认 NSTextView 接受。
        if !installing { issue = .unsupportedMutation }
        return installing
    }

    override func didChangeText() {
        // 迟到 delegate 回声不发布修订，也不向它补新 access。
        if let access, (try? contentSession.validateNative(access, owner: self)) == nil { end() }
    }

    func synchronize(_ text: String, selection: NSRange, expecting expected: CommandDraftContentAccess) {
        guard expected == access else { issue = .rejected; return }
        accept(text, selection: selection)
    }

    override func resignFirstResponder() -> Bool {
        end()
        return super.resignFirstResponder()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if window != nil, newWindow !== window { end() }
        for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
        windowObservers.removeAll()
        if let newWindow {
            for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: newWindow, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.end() }
                })
            }
        }
        super.viewWillMove(toWindow: newWindow)
    }

    nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        MainActor.assumeIsolated {
            guard !installing, editedMask.contains(.editedCharacters) else { return }
            // 这是检测后的撤权，绝不宣称接受前拦截：外部持有 mutable storage 是明确反例。
            issue = .unsupportedMutation
            end()
        }
    }

    private func accept(_ text: String, selection: NSRange) {
        guard !accepting else { issue = .reentrant; end(); return }
        guard let current = access, Range(selection, in: text) != nil else { issue = .rejected; return }
        accepting = true
        defer { accepting = false }
        do {
            let oldPoint = try contentSession.nativeRecoveryPoint(current, owner: self)
            let state = CommandDraftEditingState(parameter: parameter.rawValue, spelling: text,
                selectionLocation: selection.location, selectionLength: selection.length)
            access = try contentSession.acceptNative(state, using: current, owner: self)
            checkpointCount += 1
            #if DEBUG
            testingAfterCheckpoint?()
            #endif
            guard let next = access else { throw CommandDraftProtectionError.stale }
            try contentSession.presentNative(next, owner: self)
            registerUndo(oldPoint)
            issue = nil
        } catch {
            if access != current { end(); issue = .rejected }
            else { failed() }
        }
    }

    private func registerUndo(_ point: SealedCommandDraft) {
        localUndo.beginUndoGrouping()
        localUndo.registerUndo(withTarget: self) { editor in editor.restoreUndo(point) }
        localUndo.endUndoGrouping()
    }

    private func restoreUndo(_ point: SealedCommandDraft) {
        guard !accepting, let current = access else { issue = .rejected; return }
        accepting = true
        defer { accepting = false }
        do {
            let inverse = try contentSession.nativeRecoveryPoint(current, owner: self)
            access = try contentSession.undoNative(point, using: current, owner: self)
            checkpointCount += 1
            #if DEBUG
            testingAfterCheckpoint?()
            #endif
            guard let next = access else { throw CommandDraftProtectionError.stale }
            try contentSession.presentNative(next, owner: self)
            registerUndo(inverse)
            issue = nil
        } catch {
            if access != current { end(); issue = .rejected }
            else { failed() }
        }
    }

    private func failed() {
        issue = .rejected
        if let access, (try? contentSession.validateNative(access, owner: self)) != nil { return }
        end()
    }
}

/// NSUndoManager 在正在撤销的回调内 removeAllActions 会破坏系统分组；先禁用，栈退出后清除。
@MainActor private final class CommandNativeUndoManager: UndoManager {
    private var revoked = false

    func revoke() {
        revoked = true
        if !isUndoing && !isRedoing { removeAllActions() }
    }

    override func undo() {
        guard !revoked else { return }
        defer { if revoked { removeAllActions() } }
        super.undo()
    }

    override func redo() {
        guard !revoked else { return }
        defer { if revoked { removeAllActions() } }
        super.redo()
    }
}
