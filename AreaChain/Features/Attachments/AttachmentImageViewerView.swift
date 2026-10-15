import AppKit
import SwiftUI

struct AttachmentImageViewerView: View {
    @Bindable var session: AttachmentImageViewerSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGSize = .zero
    @State private var eventMonitors: [Any] = []
    @State private var hostWindow: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            topInfoBar
            DaybookDivider()
            canvasStage
            DaybookDivider()
            bottomToolbar
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .background(DaybookPalette.fill.page)
        .background(
            AttachmentViewerWindowAccessor { window in
                if hostWindow !== window {
                    hostWindow = window
                }
            }
        )
        .onAppear { installEventMonitors() }
        .onDisappear { removeEventMonitors() }
    }

    private var topInfoBar: some View {
        HStack(spacing: DaybookSpacing.sm) {
            if session.items.count > 1 {
                Text("\(session.currentIndex + 1) / \(session.items.count)")
                    .font(DaybookType.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, DaybookSpacing.xs)
                    .padding(.vertical, DaybookSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                            .fill(DaybookPalette.fill.subtle)
                    )
                    .accessibilityIdentifier("attachment.viewer.counter")
            }
            if let item = session.currentItem {
                Text(item.filename)
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("attachment.viewer.filename")
            }
            Spacer(minLength: DaybookSpacing.sm)
            if let item = session.currentItem, let image = session.imageLoader(item) {
                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.tertiary)
            }
        }
        .padding(.horizontal, DaybookSpacing.lg)
        .padding(.vertical, DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface)
    }

    private var canvasStage: some View {
        GeometryReader { proxy in
            ZStack {
                DaybookPalette.fill.subtle
                if let item = session.currentItem, let image = session.imageLoader(item) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(session.rotationDegrees))
                        .frame(
                            maxWidth: max(proxy.size.width - DaybookSpacing.xl * 2, 120),
                            maxHeight: max(proxy.size.height - DaybookSpacing.xl * 2, 120)
                        )
                        .scaleEffect(session.zoomScale)
                        .offset(
                            x: session.panOffset.width + dragTranslation.width,
                            y: session.panOffset.height + dragTranslation.height
                        )
                        .animation(DaybookMotion.snappy(reduceMotion), value: session.rotationQuarterTurns)
                } else if let item = session.currentItem {
                    VStack(spacing: DaybookSpacing.sm) {
                        Image(systemName: "photo")
                            .font(DaybookType.display)
                        Text(item.filename)
                            .font(DaybookType.body)
                    }
                    .foregroundStyle(DaybookPalette.text.secondary)
                }

                if session.isShowingZoomHUD {
                    zoomHUD
                        .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation(DaybookMotion.snappy(reduceMotion)) {
                    session.toggleDoubleTapZoom()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        dragTranslation = value.translation
                    }
                    .onEnded { value in
                        session.panOffset = CGSize(
                            width: session.panOffset.width + value.translation.width,
                            height: session.panOffset.height + value.translation.height
                        )
                        dragTranslation = .zero
                    }
            )
            .accessibilityIdentifier("attachment.viewer.canvas")
        }
    }

    private var zoomHUD: some View {
        Text(session.zoomPercentageText)
            .font(DaybookType.title.monospacedDigit())
            .foregroundStyle(DaybookPalette.text.onAccent)
            .padding(.horizontal, DaybookSpacing.lg)
            .padding(.vertical, DaybookSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .fill(DaybookPalette.text.primary)
            )
            .allowsHitTesting(false)
            .accessibilityIdentifier("attachment.viewer.zoomHUD")
    }

    private var bottomToolbar: some View {
        HStack(spacing: DaybookSpacing.sm) {
            Spacer(minLength: 0)
            zoomControlGroup
            toolbarSeparator
            navigationControlGroup
            toolbarSeparator
            transformControlGroup
            toolbarSeparator
            actionControlGroup
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DaybookSpacing.lg)
        .padding(.vertical, DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface)
    }

    private var zoomControlGroup: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Button {
                session.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
            .disabled(session.zoomScale <= AttachmentImageViewerSession.minZoomScale)
            .help("attachment.viewer.zoomOut")
            .accessibilityLabel("attachment.viewer.zoomOut")
            .accessibilityIdentifier("attachment.viewer.zoomOut")

            Button {
                session.resetZoom(showHUD: true)
            } label: {
                Text(session.zoomPercentageText)
                    .font(DaybookType.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 48)
            }
            .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
            .help("attachment.viewer.resetZoom")
            .accessibilityIdentifier("attachment.viewer.zoomReadout")

            Button {
                session.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
            .disabled(session.zoomScale >= AttachmentImageViewerSession.maxZoomScale)
            .help("attachment.viewer.zoomIn")
            .accessibilityLabel("attachment.viewer.zoomIn")
            .accessibilityIdentifier("attachment.viewer.zoomIn")

            Button {
                session.resetZoom(showHUD: true)
            } label: {
                Text("1:1")
                    .font(DaybookType.caption.monospacedDigit().weight(.semibold))
            }
            .buttonStyle(DaybookButtonStyle(session.isDefaultZoom ? .subtle : .active, size: .compact))
            .help("attachment.viewer.resetZoom")
            .accessibilityIdentifier("attachment.viewer.resetZoom")
        }
    }

    private var navigationControlGroup: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Button {
                session.step(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
            .disabled(!session.canGoPrevious)
            .help("calendar.prev")
            .accessibilityIdentifier("attachment.viewer.previous")

            Button {
                session.step(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
            .disabled(!session.canGoNext)
            .help("calendar.next")
            .accessibilityIdentifier("attachment.viewer.next")
        }
    }

    private var transformControlGroup: some View {
        Button {
            session.rotateClockwise()
        } label: {
            Image(systemName: "rotate.right")
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
        .help("attachment.viewer.rotate")
        .accessibilityLabel("attachment.viewer.rotate")
        .accessibilityIdentifier("attachment.viewer.rotate")
    }

    private var actionControlGroup: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Button {
                session.copyCurrentImage()
            } label: {
                Image(systemName: session.hasCopiedImage ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(DaybookButtonStyle(session.hasCopiedImage ? .iconActive : .icon, size: .regular))
            .help("attachments.copyImage")
            .accessibilityLabel("attachments.copyImage")
            .accessibilityIdentifier("attachment.viewer.copy")

            if session.onCopyToken != nil {
                Button {
                    session.copyCurrentToken()
                } label: {
                    Image(systemName: session.hasCopiedToken ? "checkmark" : "at")
                }
                .buttonStyle(DaybookButtonStyle(session.hasCopiedToken ? .iconActive : .icon, size: .regular))
                .help("attachments.copyToken")
                .accessibilityLabel("attachments.copyToken")
                .accessibilityIdentifier("attachment.viewer.copyToken")
            }

            Button {
                session.saveCurrentImageAs()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .regular))
            .help("attachment.viewer.saveAs")
            .accessibilityLabel("attachment.viewer.saveAs")
            .accessibilityIdentifier("attachment.viewer.saveAs")

            if session.onRemove != nil {
                DaybookIconButton(
                    systemName: "trash",
                    label: "alert.trash.move",
                    size: .regular,
                    role: .destructive
                ) {
                    session.removeCurrentItem()
                }
                .accessibilityIdentifier("attachment.viewer.remove")
            }
        }
    }

    private var toolbarSeparator: some View {
        Rectangle() // token-exempt: 工具栏分组竖线分隔符
            .fill(DaybookPalette.border.default)
            .frame(width: 1, height: 16)
            .padding(.horizontal, DaybookSpacing.xxs)
    }

    private func installEventMonitors() {
        removeEventMonitors()
        if let scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { event in
            guard let hostWindow, event.window === hostWindow else { return event }
            session.applyScrollDelta(event.scrollingDeltaY)
            return nil
        }) {
            eventMonitors.append(scrollMonitor)
        }
        if let magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify, handler: { event in
            guard let hostWindow, event.window === hostWindow else { return event }
            session.applyMagnification(event.magnification)
            return nil
        }) {
            eventMonitors.append(magnifyMonitor)
        }
        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard let hostWindow, event.window === hostWindow else { return event }
            return handleKeyDown(event)
        }) {
            eventMonitors.append(keyMonitor)
        }
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        if flags.isEmpty {
            if event.keyCode == 53 {
                AttachmentImageViewerWindowController.shared.close()
                return nil
            }
            if event.keyCode == 123, session.canGoPrevious {
                session.step(by: -1)
                return nil
            }
            if event.keyCode == 124, session.canGoNext {
                session.step(by: 1)
                return nil
            }
        } else if flags == .command {
            let chars = event.charactersIgnoringModifiers ?? ""
            if chars == "=" || chars == "+" {
                session.zoomIn()
                return nil
            }
            if chars == "-" {
                session.zoomOut()
                return nil
            }
            if chars == "0" {
                session.resetZoom(showHUD: true)
                return nil
            }
            if chars.lowercased() == "c" {
                session.copyCurrentImage()
                return nil
            }
        }
        return event
    }
}

private struct AttachmentViewerWindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowObservingNSView()
        view.onWindowChange = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observing = nsView as? WindowObservingNSView {
            observing.onWindowChange = onResolve
            onResolve(observing.window)
        }
    }

    private final class WindowObservingNSView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}
