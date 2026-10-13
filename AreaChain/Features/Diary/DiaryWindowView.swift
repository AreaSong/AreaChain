import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DiaryWindowView: View {
    @Bindable var session: DiaryEditorSession
    var onPin: () -> Void
    var onStateChange: () -> Void = {}
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Query private var attachments: [AttachmentItem]
    @Bindable private var shortcuts: ShortcutStore
    @State private var titleFocused = false
    @State private var editorFocused = false
    @State private var confirmsReload = false

    init(session: DiaryEditorSession, onPin: @escaping () -> Void, onStateChange: @escaping () -> Void = {},
         shortcuts: ShortcutStore? = nil) {
        self.session = session
        self.onPin = onPin
        self.onStateChange = onStateChange
        self.shortcuts = shortcuts ?? .shared
    }

    private var bodyPlaceholder: String {
        let hasTitle = !session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return L10n.string(hasTitle ? "diary.window.note.placeholder" : "diary.quick.placeholder", locale: locale)
    }

    private var visibleAttachments: [AttachmentRef] {
        guard session.canRevealContent else { return [] }
        let persisted = (session.record.map {
            CatalogChoices.attachments($0.id, in: attachments, ownerKind: .diary)
        } ?? []).filter { !session.removedAttachmentIDs.contains($0.id) }
        return persisted + session.pendingAttachments.map(\.reference)
    }

    private var inMemoryAttachmentData: [UUID: Data] {
        Dictionary(uniqueKeysWithValues: session.pendingAttachments.map { ($0.id, $0.data) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .padding(16)
        .frame(minWidth: 328, minHeight: 230)
        .background(DaybookPalette.fill.page)
        .background(
            DiaryWindowTitlebarPinAccessory(
                heading: session.windowHeading(locale: locale),
                showsUnsavedBadge: session.showsWindowUnsavedBadge,
                hasIssue: session.issue != nil,
                isPinned: session.isWindowPinned,
                truncationMode: AppPreferences.shared.contentTruncation.textTruncation,
                locale: locale,
                colorScheme: colorScheme,
                onPin: onPin
            )
        )
        .syntaxOverlayHost()
        .onAppear { editorFocused = session.canRevealContent }
        .onChange(of: session.canRevealContent) { _, value in
            if !value { titleFocused = false }
            editorFocused = value
        }
        .onChange(of: session.statusKey) { _, _ in onStateChange() }
        .onChange(of: session.title) { _, _ in onStateChange() }
        .onChange(of: session.text) { _, _ in onStateChange() }
        .confirmationDialog("diary.window.reload.title", isPresented: $confirmsReload, titleVisibility: .visible) {
            Button("diary.window.reload", role: .destructive) { session.reloadLatest() }
            Button("alert.cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private var toolbar: some View {
        if session.canRevealContent {
            DaybookInputShell(kind: .composer, focused: titleFocused, configure: { config in
                config.height = 30
                config.insets = EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            }) {
                DaybookTextField(
                    text: $session.title,
                    placeholder: L10n.string("diary.window.title.placeholder", locale: locale),
                    fontSize: DaybookType.titleSize,
                    fontWeight: .semibold,
                    focus: $titleFocused,
                    onSubmit: {
                        titleFocused = false
                        editorFocused = true
                    },
                    onCommandReturn: save,
                    commandChord: shortcuts.armedChord(for: .commitDiary),
                    allowsShiftNewline: false,
                    newlinePolicy: .searchWhitespace,
                    onMoveDown: {
                        titleFocused = false
                        editorFocused = true
                        return true
                    }
                )
                .accessibilityIdentifier("diary.window.title")
            }
        } else {
            HStack {
                Text("diary.private.title")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
            }
        }
    }

    @ViewBuilder private var content: some View {
        if session.issue == .missing {
            Text("diary.window.save.missing")
                .font(DaybookType.body).foregroundStyle(DaybookPalette.text.secondary)
        } else if !session.canRevealContent {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 26)) // token-exempt: display 令牌是 26pt light，这处是默认字重
                Text("diary.private.title").font(DaybookType.body)
                Button("diary.reveal") {
                    PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) { session.reveal() }
                }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            }
            .foregroundStyle(DaybookPalette.text.secondary)
        } else {
            DaybookInputShell(kind: .editor, focused: editorFocused) {
                SyntaxTextEditor(text: $session.text, focused: $editorFocused,
                                 placeholder: bodyPlaceholder, onSubmit: save,
                                 commandChord: shortcuts.armedChord(for: .commitDiary),
                                 onPasteImage: { pasteImage(from: $0) })
            }
        }
    }

    private var footer: some View {
        let items = visibleAttachments
        return HStack(spacing: 10) {
            if session.isSensitive && session.canRevealContent {
                Button("diary.mask") { session.mask() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            if session.canRevealContent {
                DaybookIconButton(systemName: "photo", label: "diary.attach", size: .compact, action: attach)
                DaybookIconButton(systemName: "doc.on.clipboard", label: "row.attach.paste", size: .compact) {
                    _ = pasteImage()
                }
                .accessibilityIdentifier("diary.paste")
                if !items.isEmpty {
                    DiaryAttachmentPill(
                        items: items,
                        inMemoryData: inMemoryAttachmentData,
                        hasPendingAdditions: !session.pendingAttachments.isEmpty,
                        onRemove: { item in
                            session.removeAttachment(id: item.id)
                            onStateChange()
                        }
                    )
                }
            }
            if session.issue == .conflict {
                Button("diary.window.reload") { confirmsReload = true }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            Spacer(minLength: 0)
            Button("common.save", action: save)
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .appShortcut(.saveDiary)
                .disabled(!session.canSave || !session.canRevealContent)
                .help("diary.window.save.help")
        }
        .font(DaybookType.caption)
    }

    private func save() {
        PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) {
            _ = session.save()
            onStateChange()
        }
    }

    private func attach() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) {
                let data = try Data(contentsOf: url)
                if session.stageAttachment(data: data, filename: url.lastPathComponent) {
                    session.reveal()
                    onStateChange()
                }
            }
        }
    }

    @discardableResult
    private func pasteImage(from pasteboard: NSPasteboard = .general) -> Bool {
        let staged = session.pasteAttachment(from: pasteboard)
        if staged { onStateChange() }
        return staged
    }
}

private struct DiaryWindowTitlebarBarView: View {
    let heading: String
    let showsUnsavedBadge: Bool
    let hasIssue: Bool
    let isPinned: Bool
    let truncationMode: Text.TruncationMode
    let onPin: () -> Void

    private var badgeColor: Color {
        hasIssue ? DaybookPalette.status.danger : DaybookPalette.status.pending
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(heading)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .truncationMode(truncationMode)
                    .help(heading)
                if showsUnsavedBadge {
                    HStack(spacing: 4) {
                        DaybookStatusDot(color: badgeColor, size: 6)
                        Text("diary.window.unsaved")
                            .font(DaybookType.caption)
                            .foregroundStyle(badgeColor)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .fixedSize()
                    .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("diary.window.titlebar.heading")
            DiaryWindowPinButton(isPinned: isPinned, action: onPin)
                .fixedSize()
                .layoutPriority(2)
        }
    }
}

private struct DiaryWindowPinButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isPinned ? "diary.window.unpin" : "diary.window.pin",
                  systemImage: isPinned ? "pin.fill" : "pin")
                .font(DaybookType.caption)
                .fixedSize()
        }
        .buttonStyle(DaybookButtonStyle(isPinned ? .active : .subtle, size: .compact))
        .accessibilityIdentifier("diary.window.pin")
        .accessibilityAddTraits(isPinned ? [.isSelected] : [])
    }
}

private struct DiaryWindowTitlebarPinAccessory: NSViewRepresentable {
    let heading: String
    let showsUnsavedBadge: Bool
    let hasIssue: Bool
    let isPinned: Bool
    let truncationMode: Text.TruncationMode
    let locale: Locale
    let colorScheme: ColorScheme
    let onPin: () -> Void

    func makeNSView(context: Context) -> DiaryTitlebarPinBridgeNSView {
        let view = DiaryTitlebarPinBridgeNSView()
        view.update(
            heading: heading, showsUnsavedBadge: showsUnsavedBadge, hasIssue: hasIssue,
            isPinned: isPinned, truncationMode: truncationMode,
            locale: locale, colorScheme: colorScheme, onPin: onPin
        )
        return view
    }

    func updateNSView(_ nsView: DiaryTitlebarPinBridgeNSView, context: Context) {
        nsView.update(
            heading: heading, showsUnsavedBadge: showsUnsavedBadge, hasIssue: hasIssue,
            isPinned: isPinned, truncationMode: truncationMode,
            locale: locale, colorScheme: colorScheme, onPin: onPin
        )
    }

    static func dismantleNSView(_ nsView: DiaryTitlebarPinBridgeNSView, coordinator: ()) {
        nsView.detach()
    }
}

@MainActor
private final class DiaryTitlebarPinBridgeNSView: NSView {
    private weak var attachedWindow: NSWindow?
    private var accessory: NSTitlebarAccessoryViewController?
    private var containerView: DiaryTitlebarPinContainerView?
    private var resizeObserver: NSObjectProtocol?
    private var heading = ""
    private var showsUnsavedBadge = false
    private var hasIssue = false
    private var isPinned = false
    private var truncationMode: Text.TruncationMode = .tail
    private var locale = Locale.current
    private var colorScheme: ColorScheme = .light
    private var onPin: () -> Void = {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncAttachment()
    }

    func update(
        heading: String, showsUnsavedBadge: Bool, hasIssue: Bool,
        isPinned: Bool, truncationMode: Text.TruncationMode,
        locale: Locale, colorScheme: ColorScheme, onPin: @escaping () -> Void
    ) {
        let changed = self.heading != heading
            || self.showsUnsavedBadge != showsUnsavedBadge
            || self.hasIssue != hasIssue
            || self.isPinned != isPinned
            || self.truncationMode != truncationMode
            || self.locale != locale
            || self.colorScheme != colorScheme
            || attachedWindow !== window
        self.heading = heading
        self.showsUnsavedBadge = showsUnsavedBadge
        self.hasIssue = hasIssue
        self.isPinned = isPinned
        self.truncationMode = truncationMode
        self.locale = locale
        self.colorScheme = colorScheme
        self.onPin = onPin
        if changed {
            syncAttachment()
        }
    }

    func detach() {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        if let window = attachedWindow, let accessory,
           let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
            window.removeTitlebarAccessoryViewController(at: index)
        }
        attachedWindow = nil
        accessory = nil
        containerView = nil
    }

    private func syncAttachment() {
        if attachedWindow !== window {
            detach()
        }
        guard let window, window.styleMask.contains(.titled) else { return }
        window.titleVisibility = .hidden
        let root = AnyView(
            DiaryWindowTitlebarBarView(
                heading: heading, showsUnsavedBadge: showsUnsavedBadge,
                hasIssue: hasIssue, isPinned: isPinned,
                truncationMode: truncationMode, onPin: onPin
            )
            .environment(\.locale, locale)
            .preferredColorScheme(colorScheme)
        )
        if let containerView {
            containerView.update(rootView: root, windowWidth: window.frame.width)
        } else {
            let container = DiaryTitlebarPinContainerView(rootView: root, windowWidth: window.frame.width)
            let controller = NSTitlebarAccessoryViewController()
            controller.layoutAttribute = .trailing
            controller.view = container
            window.addTitlebarAccessoryViewController(controller)
            attachedWindow = window
            accessory = controller
            containerView = container
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                MainActor.assumeIsolated {
                    guard let self, let window else { return }
                    self.containerView?.syncSize(windowWidth: window.frame.width)
                }
            }
        }
    }
}

@MainActor
private final class DiaryTitlebarPinContainerView: NSView {
    private let hostingView: NSHostingView<AnyView>
    private let leadingTrafficLightsReserve: CGFloat = 76
    private let trailingPadding: CGFloat = 10

    init(rootView: AnyView, windowWidth: CGFloat) {
        hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        super.init(frame: .zero)
        addSubview(hostingView)
        syncSize(windowWidth: windowWidth)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(rootView: AnyView, windowWidth: CGFloat) {
        hostingView.rootView = rootView
        syncSize(windowWidth: windowWidth)
    }

    func syncSize(windowWidth: CGFloat) {
        let width = max(ceil(windowWidth - leadingTrafficLightsReserve), 120)
        let height: CGFloat = 26
        if frame.size.width != width || frame.size.height < height {
            setFrameSize(NSSize(width: width, height: max(frame.height, height)))
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }

    override func layout() {
        super.layout()
        let contentWidth = max(bounds.width - trailingPadding, 0)
        let rowHeight: CGFloat = 24
        let y = floor((bounds.height - rowHeight) / 2)
        hostingView.frame = NSRect(x: 0, y: y, width: contentWidth, height: rowHeight)
    }
}
