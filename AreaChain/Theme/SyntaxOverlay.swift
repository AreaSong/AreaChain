import AppKit
import SwiftData
import SwiftUI

struct SyntaxOverlayPlacement: Equatable {
    var frame: CGRect
    var growsUpward: Bool

    static func resolve(
        anchor: CGRect,
        container: CGSize,
        preferred: CGSize,
        prefersAbove: Bool,
        matchAnchorWidth: Bool = false
    ) -> Self {
        guard CGRect(origin: .zero, size: container).intersects(anchor) else {
            return Self(frame: .zero, growsUpward: false)
        }
        let margin: CGFloat = 8
        let gap: CGFloat = 4
        let width = matchAnchorWidth
            ? min(anchor.width, container.width - margin * 2)
            : max(0, min(preferred.width, container.width - margin * 2))
        let below = max(0, container.height - margin - anchor.maxY - gap)
        let above = max(0, anchor.minY - gap - margin)
        let upward = prefersAbove ? (above >= preferred.height || above > below)
            : (below < preferred.height && above > below)
        let height = min(preferred.height, upward ? above : below)
        let x = matchAnchorWidth
            ? anchor.minX
            : min(max(margin, anchor.minX), max(margin, container.width - margin - width))
        let y = upward ? anchor.minY - gap - height : anchor.maxY + gap
        return Self(frame: CGRect(x: x, y: y, width: width, height: height), growsUpward: upward)
    }
}

struct SyntaxOverlayAnchor {
    let bounds: Anchor<CGRect>
    let state: SyntaxAutocompleteState
    var attributes: CaptureAttributes? = nil
    var prefersAbove = false
    var appearance: SyntaxOverlayAppearance

    @MainActor var preferredSize: CGSize {
        if let attributes { return CGSize(width: 280, height: min(280, 80 + CGFloat(attributes.count) * 42)) }
        var h: CGFloat = 0
        let showsSuggestions = state.isActive && !state.candidates.isEmpty
        let targetWidth: CGFloat = (state.context == .capture || state.context == .diaryCapture) ? (DaybookMetrics.Window.popoverWidth - 24) : 240

        if state.context == .diaryCapture {
            if state.showsPreview {
                h += 57
            }
            if showsSuggestions {
                if state.showsPreview { h += 1 }
                h += min(180, CGFloat(state.candidates.count) * 29 + 8) + 25
            }
            return CGSize(width: targetWidth, height: max(57, h))
        }

        let parsed = NaturalLanguageParser.parseTaskCapture(state.inputText)
        let hasMultiTags = parsed.tagNames.count > 1
        let canFitInline = LiveComposerPreviewHeader.canFit(
            title: parsed.cleanTitle,
            tags: parsed.tagNames,
            hasTime: parsed.remindMinutes != nil,
            hasPriority: parsed.hasPriorityToken,
            hasNotes: !parsed.notes.isEmpty,
            cardWidth: targetWidth
        )

        if state.showsPreview {
            h += 36
            if !showsSuggestions && hasMultiTags && !canFitInline {
                h += min(135, CGFloat(parsed.tagNames.count) * 26 + 40)
            }
        }
        if showsSuggestions {
            if state.showsPreview { h += 1 }
            h += min(180, CGFloat(state.candidates.count) * 29 + 8) + 25
        }
        return CGSize(width: targetWidth, height: max(36, h))
    }
}

struct SyntaxOverlayAppearance {
    let locale: Locale
    let colorScheme: ColorScheme
    let reduceMotion: Bool
}

struct SyntaxOverlayAnchorKey: PreferenceKey {
    static let defaultValue: [SyntaxOverlayAnchor] = []
    static func reduce(value: inout [SyntaxOverlayAnchor], nextValue: () -> [SyntaxOverlayAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private struct SyntaxOverlaySource: ViewModifier {
    @Bindable var state: SyntaxAutocompleteState
    var attributes: CaptureAttributes?
    var prefersAbove: Bool
    var enabled: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: SoftDelete.liveAttachments) private var liveAttachments: [AttachmentItem]

    func body(content: Content) -> some View {
        let presented = enabled && (attributes == nil ? state.hasPresentation : state.showsAttributes)
        content
            .onAppear { syncAvailableAttachments() }
            .onChange(of: liveAttachments.map(\.filename)) { _, _ in syncAvailableAttachments() }
            .transformAnchorPreference(key: SyntaxOverlayAnchorKey.self, value: .bounds) { anchors, bounds in
                if presented {
                    anchors.append(SyntaxOverlayAnchor(
                        bounds: bounds, state: state, attributes: attributes, prefersAbove: prefersAbove,
                        appearance: SyntaxOverlayAppearance(locale: locale, colorScheme: colorScheme, reduceMotion: reduceMotion)
                    ))
                }
            }
            .onDisappear { state.dismiss() }
    }

    private func syncAvailableAttachments() {
        guard enabled, attributes == nil, state.context.supportsAttachmentReferences else { return }
        _ = liveAttachments.count
        let names = AttachmentPoolStore.availableFilenames(in: modelContext)
        if state.availableAttachments != names {
            state.availableAttachments = names
        }
    }
}

private struct SyntaxOverlayHostModifier: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(SyntaxOverlayAnchorKey.self) { anchors in
                if enabled, let source = anchors.max(by: { $0.state.presentedAt < $1.state.presentedAt }) {
                    GeometryReader { proxy in
                        SyntaxOverlayLayer(source: source, anchors: anchors, proxy: proxy)
                            .id(source.state.id)
                    }
                }
            }
            // 最近的宿主负责呈现，检查器内的浮层不会在外层工作台重复出现。
            .transformPreference(SyntaxOverlayAnchorKey.self) { $0 = [] }
    }
}

private struct SyntaxOverlayLayer: View {
    var source: SyntaxOverlayAnchor
    var anchors: [SyntaxOverlayAnchor]
    var proxy: GeometryProxy

    var body: some View {
        let sourceAnchor = proxy[source.bounds]
        let isAttributes = source.attributes != nil
        let matchAnchorWidth = !isAttributes && (source.state.context == .capture || source.state.context == .diaryCapture)
        let anchor = resolvedAnchor(
            sourceAnchor: sourceAnchor,
            isAttributes: isAttributes,
            matchAnchorWidth: matchAnchorWidth
        )
        let placement = SyntaxOverlayPlacement.resolve(
            anchor: anchor,
            container: proxy.size,
            preferred: source.preferredSize,
            prefersAbove: source.prefersAbove,
            matchAnchorWidth: matchAnchorWidth
        )
        ZStack(alignment: .topLeading) {
            SyntaxOverlayEventMonitor(state: source.state, panelFrame: placement.frame, sourceFrame: sourceAnchor)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)
            if placement.frame.height > 0 {
                let overlayID: String = {
                    if source.attributes != nil { return "syntax.overlay.attributes" }
                    if source.state.isActive && !source.state.candidates.isEmpty { return "syntax.overlay.candidates" }
                    return "syntax.overlay.preview"
                }()
                panel(placement)
                    .environment(\.locale, source.appearance.locale)
                    .environment(\.colorScheme, source.appearance.colorScheme)
                    .frame(width: placement.frame.width, height: placement.frame.height, alignment: .top)
                    .background(SyntaxViewAnchor(overlayID))
                    .offset(x: placement.frame.minX, y: placement.frame.minY)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        .onAppear {
            for item in anchors where item.state.id != source.state.id { item.state.dismiss() }
        }
        .onDisappear { source.state.dismiss() }
    }

    private func resolvedAnchor(sourceAnchor: CGRect, isAttributes: Bool, matchAnchorWidth: Bool) -> CGRect {
        if isAttributes {
            return sourceAnchor.insetBy(dx: 0, dy: -8)
        }
        guard !matchAnchorWidth, sourceAnchor.height > 44,
              let triggerRect = source.state.triggerRectInSource else {
            return sourceAnchor
        }
        let minX = min(max(sourceAnchor.minX, sourceAnchor.minX + triggerRect.minX), max(sourceAnchor.minX, sourceAnchor.maxX - 1))
        let minY = min(max(sourceAnchor.minY, sourceAnchor.minY + triggerRect.minY), max(sourceAnchor.minY, sourceAnchor.maxY - 1))
        let width = min(max(1, triggerRect.width), max(1, sourceAnchor.maxX - minX))
        let height = min(max(1, triggerRect.height), max(1, sourceAnchor.maxY - minY))
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    @ViewBuilder
    private func panel(_ placement: SyntaxOverlayPlacement) -> some View {
        if let attributes = source.attributes {
            CaptureAttributesPopup(attributes: attributes, maxHeight: placement.frame.height, state: source.state)
        } else {
            let overlayID = (source.state.isActive && !source.state.candidates.isEmpty)
                ? "syntax.overlay.candidates"
                : "syntax.overlay.preview"
            SyntaxAutocompletePopup(
                state: source.state, growsUpward: placement.growsUpward,
                width: placement.frame.width, maxHeight: placement.frame.height, motionDisabled: source.appearance.reduceMotion
            ) { source.state.commit($0) }
            .accessibilityIdentifier(overlayID)
        }
    }
}

extension View {
    func syntaxSuggestions(_ state: SyntaxAutocompleteState, prefersAbove: Bool = false, enabled: Bool = true) -> some View {
        modifier(SyntaxOverlaySource(state: state, attributes: nil, prefersAbove: prefersAbove, enabled: enabled))
    }

    func syntaxAttributes(_ state: SyntaxAutocompleteState, attributes: CaptureAttributes) -> some View {
        modifier(SyntaxOverlaySource(state: state, attributes: attributes, prefersAbove: false, enabled: true))
    }

    func syntaxOverlayHost(enabled: Bool = true) -> some View {
        modifier(SyntaxOverlayHostModifier(enabled: enabled))
    }
}

private struct SyntaxOverlayEventMonitor: NSViewRepresentable {
    let state: SyntaxAutocompleteState
    let panelFrame: CGRect
    let sourceFrame: CGRect

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> SyntaxOverlayEventView {
        let view = SyntaxOverlayEventView()
        view.identifier = NSUserInterfaceItemIdentifier("syntax.overlay.event-monitor")
        syncView(view)
        context.coordinator.observe(view)
        return view
    }
    func updateNSView(_ view: SyntaxOverlayEventView, context: Context) {
        context.coordinator.parent = self
        syncView(view)
    }
    static func dismantleNSView(_ view: SyntaxOverlayEventView, coordinator: Coordinator) {
        view.isPresenting = false
        view.panelFrame = .zero
        coordinator.stop()
    }

    private func syncView(_ view: SyntaxOverlayEventView) {
        let active = state.hasPresentation && panelFrame.height > 0
        view.isPresenting = active
        view.panelFrame = panelFrame
        if active, let window = view.window {
            let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            if SyntaxOverlayEventView.containsWindowPoint(windowPoint, in: window) {
                BoardRowChrome.dismissActiveBubbles()
            }
        }
    }

    @MainActor
    final class Coordinator {
        var parent: SyntaxOverlayEventMonitor
        private var monitor: Any?
        private var resignObserver: NSObjectProtocol?
        init(_ parent: SyntaxOverlayEventMonitor) { self.parent = parent }

        func observe(_ view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .mouseMoved, .mouseEntered, .keyDown, .scrollWheel]
            ) { [weak self, weak view] event in
                guard let self, let view else { return event }
                let consumed = MainActor.assumeIsolated {
                    self.handleMonitoredEvent(event, view: view)
                }
                return consumed ? nil : event
            }
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak view] notification in
                MainActor.assumeIsolated {
                    guard let window = notification.object as? NSWindow, window === view?.window else { return }
                    self?.parent.state.dismiss()
                }
            }
        }

        @MainActor
        private func handleMonitoredEvent(_ event: NSEvent, view: NSView) -> Bool {
            guard let window = view.window, event.window === window,
                  parent.state.hasPresentation else { return false }
            if event.type == .keyDown {
                return handleKeyDownEscape(event, in: window)
            }
            let point = view.convert(event.locationInWindow, from: nil)
            if event.type == .mouseMoved || event.type == .mouseEntered {
                if parent.panelFrame.contains(point) {
                    BoardRowChrome.dismissActiveBubbles()
                }
                return false
            }
            if !parent.panelFrame.contains(point), !parent.sourceFrame.contains(point),
               !RowBubbleClickShieldView.containsWindowPoint(event.locationInWindow, in: window) {
                parent.state.dismiss()
            }
            return false
        }

        @MainActor
        private func handleKeyDownEscape(_ event: NSEvent, in window: NSWindow) -> Bool {
            guard event.keyCode == 53,
                  event.modifierFlags.isDisjoint(with: [.command, .control, .option, .shift]),
                  (window.firstResponder as? NSTextView)?.hasMarkedText() != true else { return false }
            if parent.state.showsAttributes {
                parent.state.dismiss()
                return true
            }
            if parent.state.isActive && !parent.state.candidates.isEmpty {
                parent.state.dismissSuggestionsOnly()
                return true
            }
            if parent.state.showsPreview {
                parent.state.dismissPreview()
                return true
            }
            parent.state.dismiss()
            return true
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
            resignObserver = nil
        }
    }
}

final class SyntaxOverlayEventView: NSView {
    private static let activeViews = NSHashTable<SyntaxOverlayEventView>.weakObjects()
    var isPresenting = false
    var panelFrame: CGRect = .zero

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            Self.activeViews.add(self)
        } else {
            Self.activeViews.remove(self)
        }
    }

    static func containsWindowPoint(_ windowPoint: NSPoint, in window: NSWindow?) -> Bool {
        guard let window else { return false }
        for view in activeViews.allObjects {
            guard view.window === window, !view.isHiddenOrHasHiddenAncestor,
                  view.isPresenting, view.panelFrame.height > 0 else { continue }
            let local = view.convert(windowPoint, from: nil)
            if view.panelFrame.contains(local) {
                return true
            }
        }
        return false
    }

    static func containsScreenPoint(_ screenPoint: NSPoint) -> Bool {
        for view in activeViews.allObjects {
            guard let window = view.window, !view.isHiddenOrHasHiddenAncestor,
                  view.isPresenting, view.panelFrame.height > 0 else { continue }
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let local = view.convert(windowPoint, from: nil)
            if view.panelFrame.contains(local) {
                return true
            }
        }
        return false
    }
}
