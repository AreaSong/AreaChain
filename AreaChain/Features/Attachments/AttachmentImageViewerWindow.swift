import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AttachmentImageViewerSession {
    static let minZoomScale: CGFloat = 0.1
    static let maxZoomScale: CGFloat = 5.0
    static let stepDelta: CGFloat = 0.2

    private(set) var items: [AttachmentRef] = []
    var currentID: UUID?
    @ObservationIgnored var imageLoader: (AttachmentRef) -> NSImage? = { _ in nil }
    @ObservationIgnored var onCopyToken: ((AttachmentRef) -> Void)?
    @ObservationIgnored var onRemove: ((AttachmentRef) -> Void)?
    @ObservationIgnored var onStateChange: (() -> Void)?
    @ObservationIgnored var onRequestClose: (() -> Void)?

    var zoomScale: CGFloat = 1.0
    var panOffset: CGSize = .zero
    var rotationQuarterTurns: Int = 0
    var isShowingZoomHUD = false
    var hasCopiedImage = false
    var hasCopiedToken = false

    @ObservationIgnored private var hudDismissWorkItem: DispatchWorkItem?

    var currentIndex: Int {
        AttachmentCarouselSelection.index(of: currentID, in: items) ?? 0
    }

    var currentItem: AttachmentRef? {
        guard !items.isEmpty else { return nil }
        return items.indices.contains(currentIndex) ? items[currentIndex] : items.first
    }

    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < items.count - 1 }

    var zoomPercentage: Int {
        Int(round(zoomScale * 100))
    }

    var zoomPercentageText: String {
        "\(zoomPercentage)%"
    }

    var rotationDegrees: Double {
        Double((rotationQuarterTurns % 4) * 90)
    }

    var isDefaultZoom: Bool {
        abs(zoomScale - 1.0) < 0.005 && panOffset == .zero
    }

    func configure(
        items: [AttachmentRef],
        initialID: UUID?,
        imageLoader: @escaping (AttachmentRef) -> NSImage?,
        onCopyToken: ((AttachmentRef) -> Void)? = nil,
        onRemove: ((AttachmentRef) -> Void)? = nil
    ) {
        self.items = items
        if let initialID, items.contains(where: { $0.id == initialID }) {
            self.currentID = initialID
        } else {
            self.currentID = items.first?.id
        }
        self.imageLoader = imageLoader
        self.onCopyToken = onCopyToken
        self.onRemove = onRemove
        resetTransform(showHUD: false)
        hasCopiedImage = false
        hasCopiedToken = false
        onStateChange?()
    }

    func setZoom(_ target: CGFloat, showHUD: Bool = true) {
        let clamped = min(max(target, Self.minZoomScale), Self.maxZoomScale)
        let snapped = abs(clamped - 1.0) < 0.015 ? 1.0 : clamped
        zoomScale = snapped
        if snapped <= 1.0 {
            panOffset = .zero
        }
        if showHUD {
            presentZoomHUD()
        }
    }

    func zoomIn() {
        let next = round((zoomScale + Self.stepDelta) * 100) / 100
        setZoom(next, showHUD: true)
    }

    func zoomOut() {
        let next = round((zoomScale - Self.stepDelta) * 100) / 100
        setZoom(next, showHUD: true)
    }

    func applyScrollDelta(_ deltaY: CGFloat) {
        guard abs(deltaY) > 0.01 else { return }
        let bounded = min(max(deltaY, -15), 15)
        let factor = 1.0 + (bounded * 0.012)
        setZoom(zoomScale * factor, showHUD: true)
    }

    func applyMagnification(_ magnification: CGFloat) {
        guard abs(magnification) > 0.001 else { return }
        let factor = max(0.2, min(2.5, 1.0 + magnification))
        setZoom(zoomScale * factor, showHUD: true)
    }

    func resetZoom(showHUD: Bool = true) {
        setZoom(1.0, showHUD: showHUD)
        panOffset = .zero
    }

    func toggleDoubleTapZoom() {
        if abs(zoomScale - 1.0) > 0.05 {
            resetZoom(showHUD: true)
        } else {
            panOffset = .zero
            setZoom(2.0, showHUD: true)
        }
    }

    func rotateClockwise() {
        rotationQuarterTurns = (rotationQuarterTurns + 1) % 4
        panOffset = .zero
    }

    func step(by delta: Int) {
        guard let next = AttachmentCarouselSelection.adjacentID(from: currentID, delta: delta, in: items) else { return }
        currentID = next
        resetTransform(showHUD: false)
        hasCopiedImage = false
        hasCopiedToken = false
        onStateChange?()
    }

    func copyCurrentImage() {
        guard let item = currentItem,
              let image = imageLoader(item),
              let pngData = ImageBytes.png(from: image) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)
        hasCopiedImage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.hasCopiedImage = false
        }
    }

    func copyCurrentToken() {
        guard let item = currentItem, let onCopyToken else { return }
        onCopyToken(item)
        hasCopiedToken = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.hasCopiedToken = false
        }
    }

    func saveCurrentImageAs() {
        guard let item = currentItem,
              let image = imageLoader(item),
              let pngData = ImageBytes.png(from: image) else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = item.filename.lowercased().hasSuffix(".png")
            ? item.filename
            : "\(item.filename).png"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        try? pngData.write(to: destinationURL, options: .atomic)
    }

    func removeCurrentItem() {
        guard let item = currentItem, let onRemove else { return }
        let nextID = AttachmentCarouselSelection.nextIDAfterRemoving(item.id, in: items)
        items.removeAll { $0.id == item.id }
        currentID = nextID
        resetTransform(showHUD: false)
        onRemove(item)
        onStateChange?()
        if items.isEmpty {
            onRequestClose?()
        }
    }

    private func resetTransform(showHUD: Bool) {
        hudDismissWorkItem?.cancel()
        zoomScale = 1.0
        panOffset = .zero
        rotationQuarterTurns = 0
        isShowingZoomHUD = showHUD
    }

    private func presentZoomHUD() {
        hudDismissWorkItem?.cancel()
        isShowingZoomHUD = true
        let work = DispatchWorkItem { [weak self] in
            self?.isShowingZoomHUD = false
        }
        hudDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }
}

@MainActor
final class AttachmentImageViewerWindowController: NSObject, NSWindowDelegate {
    static let shared = AttachmentImageViewerWindowController()
    static let defaultContentSize = NSSize(width: 820, height: 620)
    static let minimumContentSize = NSSize(width: 520, height: 400)

    let session = AttachmentImageViewerSession()
    private(set) var hostedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var preferenceObservation: PreferenceObservation?

    override init() {
        super.init()
        AppWindows.attachmentViewerWindowProvider = { [weak self] in
            [self?.hostedWindow].compactMap { $0 }
        }
        session.onStateChange = { [weak self] in
            self?.refreshWindowChrome()
        }
        session.onRequestClose = { [weak self] in
            self?.close()
        }
        preferenceObservation = PreferenceObservation(
            preferences: AppPreferences.shared,
            consumer: .windowChrome,
            presentation: { [weak self] in self?.refreshWindowChrome() },
            legacy: { [weak self] in self?.refreshWindowChrome() }
        )
        installPrivacyObservers()
    }

    func show(
        items: [AttachmentRef],
        initialID: UUID?,
        imageLoader: @escaping (AttachmentRef) -> NSImage?,
        onCopyToken: ((AttachmentRef) -> Void)? = nil,
        onRemove: ((AttachmentRef) -> Void)? = nil,
        activate: Bool = true
    ) {
        guard !items.isEmpty else { return }
        session.configure(
            items: items,
            initialID: initialID,
            imageLoader: imageLoader,
            onCopyToken: onCopyToken,
            onRemove: onRemove
        )
        let isCreatingWindow = hostedWindow == nil
        if isCreatingWindow {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.identifier = NSUserInterfaceItemIdentifier("attachment.viewer.window")
            window.contentMinSize = Self.minimumContentSize
            window.minSize = Self.minimumContentSize
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            let hosting = NSHostingController(
                rootView: AnyView(AttachmentImageViewerView(session: session).appChrome())
            )
            hosting.sizingOptions = []
            window.contentViewController = hosting
            AppWindows.centerWindow(window, size: Self.defaultContentSize)
            hostedWindow = window
        }
        refreshWindowChrome()
        if activate {
            AppWindows.activateForOpening()
        }
        if hostedWindow?.isMiniaturized == true {
            hostedWindow?.deminiaturize(nil)
        }
        hostedWindow?.makeKeyAndOrderFront(nil)
    }

    func close() {
        hostedWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === hostedWindow else { return }
        closing.makeFirstResponder(nil)
        if let host = closing.contentViewController as? NSHostingController<AnyView> {
            host.rootView = AnyView(EmptyView())
            host.view.layoutSubtreeIfNeeded()
        }
        closing.contentViewController = nil
        closing.contentView = nil
        closing.delegate = nil
        hostedWindow = nil
        AppWindows.resignIfIdle(closing: closing)
        DispatchQueue.main.async { [weak closing] in
            AppWindows.resignIfIdle(closing: closing)
        }
    }

    private func refreshWindowChrome() {
        guard let window = hostedWindow else { return }
        let locale = AppPreferences.shared.resolvedLocale
        let baseTitle = L10n.string("attachments.view", locale: locale)
        if let item = session.currentItem {
            if session.items.count > 1 {
                window.title = "\(session.currentIndex + 1) / \(session.items.count) · \(item.filename)"
            } else {
                window.title = item.filename
            }
        } else {
            window.title = baseTitle
        }
    }

    private func installPrivacyObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .privacyWillLock, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        })
        observers.append(center.addObserver(forName: .privacyMask, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        })
    }
}
