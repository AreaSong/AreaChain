import AppKit
import SwiftUI

@Observable
@MainActor
final class SyntaxAutocompleteState {
    let id = UUID()
    let context: SyntaxInputContext
    var allowsLivePreview: Bool = false
    var isActive: Bool = false
    var trigger: SyntaxTrigger? = nil
    var candidates: [SyntaxCandidate] = []
    var selectedIndex: Int = 0
    var showsAttributes = false
    var presentedAt: TimeInterval = 0
    var inputText: String = ""
    var isDismissedByUser: Bool = false
    var availableTags: [String] = []
    @ObservationIgnored weak var editor: NSTextView?
    @ObservationIgnored var restoreEditing: (() -> Void)?

    var showsPreview: Bool {
        guard allowsLivePreview, (context == .capture || context == .diaryCapture), !isDismissedByUser else { return false }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasPresentation: Bool {
        (isActive && !candidates.isEmpty) || showsAttributes || showsPreview
    }

    init(context: SyntaxInputContext = .capture, allowsLivePreview: Bool = false) {
        self.context = context
        self.allowsLivePreview = allowsLivePreview
    }

    func update(text: String, cursorLocation: Int, availableTags: [String] = []) {
        let textChanged = text != inputText
        inputText = text
        self.availableTags = availableTags
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || textChanged {
            isDismissedByUser = false
        }
        if showsPreview && presentedAt == 0 {
            presentedAt = ProcessInfo.processInfo.systemUptime
        }
        guard let detected = SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: cursorLocation) else {
            dismissSuggestionsOnly()
            return
        }

        let items = SyntaxAutocompleteEngine.candidates(for: detected, availableTags: availableTags, context: context)
        guard !items.isEmpty else {
            dismissSuggestionsOnly()
            return
        }

        isDismissedByUser = false
        trigger = detected
        candidates = items
        selectedIndex = max(0, min(selectedIndex, items.count - 1))
        if !isActive { presentedAt = ProcessInfo.processInfo.systemUptime }
        showsAttributes = false
        isActive = true
    }

    func selectPrevious() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
    }

    func selectNext() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % candidates.count
    }

    func selectedCandidate() -> SyntaxCandidate? {
        guard isActive, !candidates.isEmpty, selectedIndex >= 0, selectedIndex < candidates.count else {
            return nil
        }
        return candidates[selectedIndex]
    }

    /// 鼠标和键盘都走原生编辑，避免绑定整段覆盖破坏撤销范围与光标。
    @discardableResult
    func commit(_ candidate: SyntaxCandidate, in textView: NSTextView? = nil) -> Bool {
        guard isActive, let trigger, let editor = textView ?? self.editor,
              !editor.hasMarkedText(), trigger.range.location != NSNotFound,
              NSMaxRange(trigger.range) <= (editor.string as NSString).length else { return false }
        if candidate.id == "tag_empty_guide" {
            dismissSuggestionsOnly()
            return true
        }
        let cursor = trigger.range.location + (candidate.insertText as NSString).length
        editor.breakUndoCoalescing()
        editor.insertText(candidate.insertText, replacementRange: trigger.range)
        editor.setSelectedRange(NSRange(location: cursor, length: 0))
        editor.breakUndoCoalescing()
        dismissSuggestionsOnly()
        return true
    }

    func dismissSuggestionsOnly() {
        isActive = false
        trigger = nil
        candidates = []
        selectedIndex = 0
    }

    func dismissPreview() {
        isDismissedByUser = true
    }

    func dismiss() {
        dismissSuggestionsOnly()
        showsAttributes = false
    }

    func reset() {
        dismiss()
        isDismissedByUser = false
        inputText = ""
        presentedAt = 0
    }

    func showAttributes() {
        guard editor?.hasMarkedText() != true else { return }
        restoreEditing?()
        dismiss()
        showsAttributes = true
        presentedAt = ProcessInfo.processInfo.systemUptime
    }

    static func forResponder(_ responder: NSResponder?) -> SyntaxAutocompleteState? {
        guard let editor = responder as? NSTextView else { return nil }
        if let coordinator = editor.delegate as? DaybookTextEditor.Coordinator { return coordinator.parent.autocomplete }
        guard let field = (editor.delegate as AnyObject?) as? DaybookAppKitTextField,
              let coordinator = field.delegate as? DaybookTextField.Coordinator else { return nil }
        return coordinator.parent.autocomplete
    }
}

struct SyntaxAutocompletePopup: View {
    @Bindable var state: SyntaxAutocompleteState
    var growsUpward = false
    var width: CGFloat = 316
    var maxHeight: CGFloat = 260
    var motionDisabled = false
    var onCommit: (SyntaxCandidate) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    private func previewHeader(showsSuggestions: Bool) -> some View {
        if state.context == .diaryCapture {
            LiveDiaryComposerPreview(
                text: state.inputText,
                availableTags: state.availableTags,
                showsSuggestions: showsSuggestions,
                onClose: dismissPreview
            )
        } else {
            LiveComposerPreviewHeader(
                text: state.inputText,
                knownTags: state.availableTags,
                activeCandidate: showsSuggestions ? state.selectedCandidate() : nil,
                showsSuggestions: showsSuggestions,
                onClose: dismissPreview
            )
        }
    }

    private func dismissPreview() {
        withAnimation(DaybookMotion.interactive(reduceMotion || motionDisabled)) {
            state.dismissPreview()
        }
    }

    @ViewBuilder
    private func popoverBackground(isStandalonePreview: Bool) -> some View {
        if !isStandalonePreview {
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .fill(DaybookPalette.fill.page)
                .daybookElevation(.floating)
        }
    }

    @ViewBuilder
    private func popoverBorder(isStandalonePreview: Bool) -> some View {
        if !isStandalonePreview {
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7) // token-exempt: 70% 分隔线没有对应令牌
        }
    }

    var body: some View {
        let showsPreview = state.showsPreview
        let showsSuggestions = state.isActive && !state.candidates.isEmpty
        let isStandalonePreview = showsPreview && !showsSuggestions

        if showsPreview || showsSuggestions {
            VStack(alignment: .leading, spacing: 0) {
                if showsPreview {
                    previewHeader(showsSuggestions: showsSuggestions)
                }

                if showsPreview && showsSuggestions {
                    DaybookDivider(opacity: 0.4)
                }

                if showsSuggestions {
                    candidateList
                    DaybookDivider(opacity: 0.5)
                    footerGuide
                }
            }
            .frame(width: width)
            .background(popoverBackground(isStandalonePreview: isStandalonePreview))
            .overlay(popoverBorder(isStandalonePreview: isStandalonePreview))
            .transition((reduceMotion || motionDisabled) ? .identity : .opacity.combined(with: .scale(
                scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading
            )))
            .accessibilityElement(children: .contain)
        }
    }

    private var candidateList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(state.candidates.enumerated()), id: \.element.id) { index, item in
                        Button { onCommit(item) } label: {
                            candidateRow(item, isSelected: index == state.selectedIndex)
                        }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                        .focusable(false)
                        .background(SyntaxViewAnchor("syntax.candidate." + item.id))
                        .accessibilityIdentifier("syntax.candidate." + item.id)
                        .accessibilityAddTraits(index == state.selectedIndex ? [.isSelected] : [])
                        .id(item.id)
                    }
                }
                .padding(4)
            }
            .daybookScroll()
            .frame(height: max(0, min(180, CGFloat(state.candidates.count) * 29 + 8, maxHeight - 25)))
            .onChange(of: state.selectedIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < state.candidates.count {
                    withAnimation(DaybookMotion.interactive(reduceMotion || motionDisabled)) {
                        proxy.scrollTo(state.candidates[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func candidateRow(_ item: SyntaxCandidate, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            iconView(for: item)
                .frame(width: 16, height: 16)

            Text(item.title)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced)) // token-exempt: 等宽候选标题，kbd 是 8.5pt
                .foregroundStyle(DaybookPalette.text.primary)

            Spacer(minLength: 4)

            if let subtitle = item.subtitle {
                Text(LocalizedStringKey(subtitle))
                    .font(DaybookType.badge.weight(.regular))
                    .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(isSelected ? DaybookPalette.accent.fill : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func iconView(for item: SyntaxCandidate) -> some View {
        switch item.kind {
        case .tag:
            if item.isCreation {
                Image(systemName: "plus.circle.fill")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.Syntax.tag)
            } else {
                Image(systemName: "tag.fill")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.Syntax.tag)
            }
        case .priority:
            Image(systemName: "exclamationmark.circle.fill")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.Syntax.priorityColor(for: item.title))
        case .time:
            Image(systemName: "clock.fill")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.Syntax.time)
        }
    }

    private var footerGuide: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("↑↓")
                    .font(DaybookType.kbd)
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06))) // token-exempt: 6% 墨色没有对应令牌
                Text("syntax.footer.navigate")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            HStack(spacing: 3) {
                Text("⇥ / ↵")
                    .font(DaybookType.kbd)
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06))) // token-exempt: 6% 墨色没有对应令牌
                Text("syntax.footer.complete")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Text("Esc")
                    .font(DaybookType.kbd)
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06))) // token-exempt: 6% 墨色没有对应令牌
                Text("syntax.footer.dismiss")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(DaybookPalette.text.primary.opacity(0.02)) // token-exempt: 2% 墨色没有对应令牌
    }
}

extension Notification.Name {
    static let diaryAppendToken = Notification.Name("AreaChain.diaryAppendToken")
}
