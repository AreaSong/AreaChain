import AppKit

/// 显式隔离装配的命令编辑器。应用接收到的纯文本/组合状态先提交恢复点，再更新原生显示。
/// 系统候选窗与 mutable storage 旁路不在受控事务承诺内。
@MainActor final class CommandProtectedTextView: DaybookAppKitTextView, CommandDraftNativeOwner, NSTextStorageDelegate {
    enum Issue: Equatable { case unavailable, rejected, acceptedNotDisplayed, unsupportedMutation, reentrant }
    let parameter: CommandParameterID
    private let contentSession: CommandDraftContentSession
    private var localUndo = CommandNativeUndoManager()
    private(set) var access: CommandDraftContentAccess?
    private(set) var issue: Issue?
    private(set) var checkpointCount = 0
    var onRevision: (() -> Void)?
    var onEnd: (() -> Void)?
    private var compositionUndo: Recovery?
    private(set) var pendingConfirmation = false
    private var installing = false
    private var accepting = false
    private var windowObservers: [NSObjectProtocol] = []
    #if DEBUG
    var testingAfterCheckpoint: (() -> Void)?
    var testingBeforeMarkedText: (() -> Void)?
    #endif

    init(session: CommandDraftContentSession, parameter: CommandParameterID = .notes) {
        self.parameter = parameter
        contentSession = session
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 200), textContainer: container)
        // 指定 frame 初始化会把 maxSize 固定为 400×200；宿主启用纵向伸缩后必须允许全文高度，
        // 否则末尾虽有字符和检查点，滚动与 NSTextInputClient 候选锚点仍被裁在旧高度内。
        maxSize.height = CGFloat.greatestFiniteMagnitude
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
            isEditable = try contentSession.nativeOperation(restored, parameter: parameter).requiresValue
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
        compositionUndo = nil
        pendingConfirmation = false
        isEditable = false
        installing = true
        defer { installing = false }
        inputContext?.discardMarkedText()
        super.unmarkText()
        super.string = ""
        super.setSelectedRange(NSRange(location: 0, length: 0))
        localUndo.revoke()
        onEnd?()
    }

    func installProtectedContents(_ state: CommandDraftEditingState) throws {
        guard contentSession.permitsNativeInstallation(self), state.parameter == parameter.rawValue else { throw CommandDraftProtectionError.invalidPayload }
        installing = true
        defer { installing = false }
        try CommandTextTiming.measure("nativeValidate") { try state.validate() }
        pendingConfirmation = state.composition?.pendingConfirmation == true
        if let composition = state.composition, !composition.pendingConfirmation {
            let local = NSRange(location: state.selectionLocation - composition.location, length: state.selectionLength)
            guard CommandDraftEditingState.valid(local, in: composition.text) else { throw CommandDraftProtectionError.invalidPayload }
            if super.hasMarkedText(), super.markedRange().location == composition.location {
                // 已核验的同一组合只更新局部 marked 范围；重装整篇会让长文布局逐次失效。
                if !(super.string as NSString).isEqual(to: state.spelling) {
                    CommandTextTiming.measure("nativeMarked") {
                        super.setMarkedText(composition.text, selectedRange: local, replacementRange: super.markedRange())
                    }
                }
            } else {
                super.unmarkText()
                try replaceDisplay(with: state.confirmedText)
                CommandTextTiming.measure("nativeMarked") {
                    super.setMarkedText(composition.text, selectedRange: local,
                        replacementRange: NSRange(location: composition.location, length: composition.replacedText.utf16.count))
                }
            }
        } else {
            super.unmarkText()
            try replaceDisplay(with: state.spelling)
        }
        guard contentSession.permitsNativeInstallation(self) else { throw CommandDraftProtectionError.stale }
        if super.selectedRange() != state.selection {
            CommandTextTiming.measure("selection") { super.setSelectedRange(state.selection) }
        }
        guard textStorage != nil, (super.string as NSString).isEqual(to: state.spelling), selectedRange() == state.selection else {
            throw CommandDraftProtectionError.unavailable
        }
    }

    private func replaceDisplay(with text: String) throws {
        guard !(super.string as NSString).isEqual(to: text) else { return }
        let delta = CommandTextTiming.measure("difference") { CommandNativeTextInput.difference(from: super.string, to: text) }
        guard contentSession.permitsNativeInstallation(self), let storage = textStorage else {
            throw CommandDraftProtectionError.stale
        }
        CommandTextTiming.measure("storage") {
            storage.beginEditing()
            storage.replaceCharacters(in: delta.range, with: delta.text)
            storage.endEditing()
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
        if installing { super.insertText(insertString, replacementRange: replacementRange); return }
        guard let text = CommandNativeTextInput.text(insertString) else { issue = .unsupportedMutation; return }
        transform { try CommandNativeTextInput.insert(text, range: replacementRange, in: $0) }
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

    override func insertNewline(_ sender: Any?) {
        if hasMarkedText() || pendingConfirmation { confirmPendingInput(); return }
        insertText("\n", replacementRange: selectedRange())
    }
    override func insertTab(_ sender: Any?) { insertText("\t", replacementRange: selectedRange()) }
    override func cancelOperation(_ sender: Any?) {
        if hasMarkedText() || pendingConfirmation { transform { $0.cancellingComposition() } }
        else { window?.makeFirstResponder(nil); end() }
    }

    func confirmPendingInput() { transform { $0.confirmingComposition() } }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        if flags.contains(.command), event.keyCode == UInt16(ShortcutKey.returnKey) { return true }
        // 默认 NSTextView 撤销已关闭，键盘必须明确路由到本控件的受控历史。
        if event.charactersIgnoringModifiers?.lowercased() == "z", flags == .command || flags == [.command, .shift] {
            if hasMarkedText() || pendingConfirmation { cancelOperation(nil) }
            else if flags.contains(.shift) { localUndo.redo() }
            else { localUndo.undo() }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, let text = pboard.string(forType: .string), let previous = access else { return false }
        insertText(text, replacementRange: selectedRange())
        return access != nil && access != previous
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool { false }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        if installing { super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange); return }
        #if DEBUG
        testingBeforeMarkedText?()
        #endif
        guard let text = CommandNativeTextInput.text(string) else { issue = .unsupportedMutation; return }
        transform { try CommandNativeTextInput.mark(text, selection: selectedRange, range: replacementRange, in: $0) }
    }

    override func unmarkText() {
        if installing { super.unmarkText() }
        else { confirmPendingInput() }
    }

    override func setSelectedRange(_ charRange: NSRange) {
        if installing { super.setSelectedRange(charRange) }
        else { select(charRange) }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        if installing { super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag); return }
        guard ranges.count == 1 else { issue = .unsupportedMutation; return }
        select(ranges[0].rangeValue)
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
        transform { _ in .init(parameter: self.parameter.rawValue, spelling: text, selectionLocation: selection.location, selectionLength: selection.length) }
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

    private enum Recovery {
        case protected(SealedCommandDraft)
        case ordinary(CommandDraftEditingState)
    }

    private func point(_ current: CommandDraftContentAccess) throws -> Recovery {
        if current.isProtected { return .protected(try contentSession.nativeRecoveryPoint(current, owner: self)) }
        return .ordinary(try contentSession.nativeState(current, owner: self))
    }

    private func select(_ range: NSRange) {
        transform(selectionOnly: true) { state in
            var next = state
            next.selectionLocation = range.location
            next.selectionLength = range.length
            if let composition = next.composition,
               range.location < composition.location || NSMaxRange(range) > NSMaxRange(composition.range) {
                next.composition?.pendingConfirmation = true
            }
            return next
        }
    }

    private func transform(selectionOnly: Bool = false, _ make: (CommandDraftEditingState) throws -> CommandDraftEditingState) {
        guard !accepting else { issue = .reentrant; end(); return }
        guard let current = access else { issue = issue ?? .rejected; return }
        accepting = true
        var committed = false
        defer { accepting = false }
        do {
            let before = try CommandTextTiming.measure("readState") { try contentSession.nativeState(current, owner: self) }
            let candidate = try CommandTextTiming.measure("candidate") { try make(before) }
            try CommandTextTiming.measure("validateCandidate") { try candidate.validate() }
            if candidate == before { return }
            let oldPoint = try point(current)
            access = try CommandTextTiming.measure("accept") { try contentSession.acceptNative(candidate, using: current, owner: self) }
            committed = true
            checkpointCount += 1
            #if DEBUG
            testingAfterCheckpoint?()
            #endif
            guard let next = access else { throw CommandDraftProtectionError.stale }
            try CommandTextTiming.measure("nativeInstall") { try contentSession.presentNative(next, owner: self) }
            if !selectionOnly {
                if before.composition == nil, candidate.composition != nil { compositionUndo = oldPoint }
                if candidate.composition == nil {
                    if before.composition != nil {
                        if candidate.spelling != before.confirmedText { registerUndo(compositionUndo ?? oldPoint) }
                        compositionUndo = nil
                    } else if candidate.spelling != before.spelling { registerUndo(oldPoint) }
                }
            }
            issue = nil
            onRevision?()
        } catch {
            if access != current { end(); issue = committed ? .acceptedNotDisplayed : .rejected; onRevision?() }
            else { failed(); onRevision?() }
        }
    }

    private func registerUndo(_ point: Recovery) {
        CommandTextTiming.measure("undoRegister") {
            localUndo.beginUndoGrouping()
            localUndo.registerUndo(withTarget: self) { editor in editor.restoreUndo(point) }
            localUndo.endUndoGrouping()
        }
    }

    private func restoreUndo(_ point: Recovery) {
        guard !accepting, let current = access else { issue = .rejected; return }
        accepting = true
        var committed = false
        defer { accepting = false }
        do {
            let inverse = try self.point(current)
            switch point {
            case .protected(let envelope): access = try contentSession.undoNative(envelope, using: current, owner: self)
            case .ordinary(let state): access = try contentSession.acceptNative(state, using: current, owner: self)
            }
            committed = true
            checkpointCount += 1
            #if DEBUG
            testingAfterCheckpoint?()
            #endif
            guard let next = access else { throw CommandDraftProtectionError.stale }
            try CommandTextTiming.measure("nativeInstall") { try contentSession.presentNative(next, owner: self) }
            registerUndo(inverse)
            issue = nil
            onRevision?()
        } catch {
            if access != current { end(); issue = committed ? .acceptedNotDisplayed : .rejected; onRevision?() }
            else { failed(); onRevision?() }
        }
    }

    func changeOperation(_ operation: CommandFieldOperation) throws {
        guard let current = access, !accepting else { throw CommandDraftProtectionError.stale }
        accepting = true
        defer { accepting = false }
        access = try contentSession.changeNativeOperation(operation, using: current, owner: self)
        guard let next = access else { throw CommandDraftProtectionError.stale }
        try contentSession.presentNative(next, owner: self)
        isEditable = operation.requiresValue
        localUndo.removeAllActions()
        end()
        onRevision?()
    }

    private func failed() {
        issue = .rejected
        if let access, (try? contentSession.validateNative(access, owner: self)) != nil { return }
        end()
    }
}
