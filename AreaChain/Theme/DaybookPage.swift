import SwiftData
import SwiftUI

enum DaybookTitleStyle {
    case page
    case entity
}

struct DaybookPage<Trailing: View, Content: View>: View {
    @Environment(\.workspaceEmbedded) private var embedded
    var title: LocalizedStringKey?
    var titleText: String?
    var titleStyle: DaybookTitleStyle
    var systemImage: String?
    var subtitle: LocalizedStringKey?
    var subtitleText: String?
    var minWidth: CGFloat
    var minHeight: CGFloat
    var fullWidth: Bool
    var trailing: Trailing
    var content: Content

    init(
        title: LocalizedStringKey? = nil,
        titleText: String? = nil,
        titleStyle: DaybookTitleStyle = .page,
        systemImage: String? = nil,
        subtitle: LocalizedStringKey? = nil,
        subtitleText: String? = nil,
        minWidth: CGFloat = 480,
        minHeight: CGFloat = 480,
        fullWidth: Bool = false,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleText = titleText
        self.titleStyle = titleStyle
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.subtitleText = subtitleText
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.fullWidth = fullWidth
        self.trailing = trailing()
        self.content = content()
    }

    private var showsHeader: Bool {
        title != nil || titleText != nil || subtitle != nil || subtitleText != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            if showsHeader && (!embedded || titleStyle == .entity) {
                DaybookPageHeader {
                    titleLabel
                } subtitle: {
                    subtitleLabel
                } trailing: {
                    trailing
                }
            }
            content
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(.horizontal, DaybookSpacing.page)
        .padding(.top, embedded ? 0 : DaybookSpacing.page)
        .padding(.bottom, embedded ? WorkspaceLayout.embeddedPageBottomInset : DaybookSpacing.page)
        // 独立页面的最小尺寸不能反向撑大工作台；嵌入时由三栏布局分配空间。
        .frame(
            minWidth: embedded ? 0 : minWidth,
            maxWidth: .infinity,
            minHeight: embedded ? 0 : minHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(embedded ? Color(nsColor: .windowBackgroundColor) : DaybookPalette.fill.page) // token-exempt: 工作台嵌入时使用系统灰底
    }

    @ViewBuilder
    private var titleLabel: some View {
        if titleText != nil || title != nil {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(titleFont)
                        .foregroundStyle(DaybookPalette.accent.base)
                }
                if let titleText {
                    Text(titleText)
                        .font(titleFont)
                        .foregroundStyle(DaybookPalette.text.primary)
                } else if let title {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(DaybookPalette.text.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleLabel: some View {
        if let subtitleText {
            Text(subtitleText)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
        } else if let subtitle {
            Text(subtitle)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private var titleFont: Font {
        switch titleStyle {
        case .page: DaybookType.title
        case .entity: DaybookType.entity
        }
    }
}

extension DaybookPage where Trailing == EmptyView {
    init(
        title: LocalizedStringKey? = nil,
        titleText: String? = nil,
        titleStyle: DaybookTitleStyle = .page,
        systemImage: String? = nil,
        subtitle: LocalizedStringKey? = nil,
        subtitleText: String? = nil,
        minWidth: CGFloat = 480,
        minHeight: CGFloat = 480,
        fullWidth: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            titleText: titleText,
            titleStyle: titleStyle,
            systemImage: systemImage,
            subtitle: subtitle,
            subtitleText: subtitleText,
            minWidth: minWidth,
            minHeight: minHeight,
            fullWidth: fullWidth,
            trailing: { EmptyView() },
            content: content
        )
    }
}

struct DaybookComposer<Accessory: View>: View {
    @Binding var text: String
    var placeholder: String
    var focus: Binding<Bool>?
    var availableTags: [String] = []
    var allowsShiftNewline: Bool
    var onSubmit: () -> Void
    var onCommandReturn: (() -> Void)?
    var accessory: Accessory

    @Environment(\.locale) private var locale
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var fallbackFocus = false
    @State private var autocomplete = SyntaxAutocompleteState(context: .capture, allowsLivePreview: true)

    init(
        text: Binding<String>,
        placeholder: String,
        focus: Binding<Bool>? = nil,
        availableTags: [String] = [],
        allowsShiftNewline: Bool = true,
        onSubmit: @escaping () -> Void,
        onCommandReturn: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self._text = text
        self.placeholder = placeholder
        self.focus = focus
        self.availableTags = availableTags
        self.allowsShiftNewline = allowsShiftNewline
        self.onSubmit = onSubmit
        self.onCommandReturn = onCommandReturn
        self.accessory = accessory()
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFocused: Bool {
        focus?.wrappedValue ?? fallbackFocus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DaybookInputShell(kind: .composer, focused: isFocused) {
                Image(systemName: "plus")
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(isFocused ? DaybookPalette.text.primary : DaybookPalette.text.secondary.opacity(0.8)) // token-exempt: 80% 次要色没有对应令牌
                    .frame(width: 14)
            } field: {
                field
            } trailing: {
                CaptureAttributesButton(text: text, knownTags: completionTags, state: autocomplete)
                Button("row.add", action: onSubmit)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .disabled(!canSubmit)
            }
            .syntaxSuggestions(autocomplete)
            accessory
        }
    }

    @ViewBuilder
    private var field: some View {
        DaybookTextField(
            text: $text,
            placeholder: L10n.string(String.LocalizationValue(stringLiteral: placeholder), locale: locale),
            focus: focus ?? $fallbackFocus,
            autocomplete: autocomplete,
            availableTags: completionTags,
            onSubmit: onSubmit,
            onCommandReturn: onCommandReturn,
            allowsShiftNewline: allowsShiftNewline
        )
    }

    private var completionTags: [String] {
        availableTags.isEmpty ? Catalog.liveTaskTags(tags).map(\.name) : availableTags
    }
}

extension DaybookComposer where Accessory == EmptyView {
    init(
        text: Binding<String>,
        placeholder: String,
        focus: Binding<Bool>? = nil,
        availableTags: [String] = [],
        allowsShiftNewline: Bool = true,
        onSubmit: @escaping () -> Void,
        onCommandReturn: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            focus: focus,
            availableTags: availableTags,
            allowsShiftNewline: allowsShiftNewline,
            onSubmit: onSubmit,
            onCommandReturn: onCommandReturn,
            accessory: { EmptyView() }
        )
    }
}

// MARK: - 滑动模式公用外壳（固定单行录入槽 + 固定单行筛选槽 + 顶部 18pt 原生渐进高斯模糊滚动槽）

struct DaybookScrollablePageShell<Composer: View, FilterBar: View, Content: View>: View {
    private let composer: Composer
    private let filterBar: FilterBar
    private let content: Content

    init(
        @ViewBuilder composer: () -> Composer,
        @ViewBuilder filterBar: () -> FilterBar,
        @ViewBuilder content: () -> Content
    ) {
        self.composer = composer()
        self.filterBar = filterBar()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            composer
                .zIndex(30)
            filterBar
                .zIndex(20)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .daybookTopScrollBlur(height: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 滚动交界处原生渐进高斯模糊（未滚动时完全透明，向上滑动时对进入顶部边缘的内容产生原生毛玻璃渐隐）

extension View {
    func daybookTopScrollBlur(
        height: CGFloat = 18,
        material: NSVisualEffectView.Material = .headerView
    ) -> some View {
        overlay(alignment: .top) {
            DaybookTopScrollBlurRepresentable(height: height, material: material)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .allowsHitTesting(false)
        }
    }
}

private struct DaybookTopScrollBlurRepresentable: NSViewRepresentable {
    var height: CGFloat
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> DaybookTopScrollBlurNSView {
        let view = DaybookTopScrollBlurNSView()
        view.configure(height: height, material: material)
        return view
    }

    func updateNSView(_ nsView: DaybookTopScrollBlurNSView, context: Context) {
        nsView.configure(height: height, material: material)
    }

    static func dismantleNSView(_ nsView: DaybookTopScrollBlurNSView, coordinator: ()) {
        nsView.dismantle()
    }
}

final class DaybookTopScrollBlurNSView: NSView {
    private let effectView = NSVisualEffectView()
    private weak var observedScrollView: NSScrollView?
    private var observers: [NSObjectProtocol] = []
    private var blurHeight: CGFloat = 18
    private var lastMaskSize: NSSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.alphaValue = 0
        effectView.autoresizingMask = [.width, .height]
        addSubview(effectView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(height: CGFloat, material: NSVisualEffectView.Material) {
        blurHeight = height
        if effectView.material != material {
            effectView.material = material
        }
        bindIfNeeded()
        updateBlurVisibility()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        bindIfNeeded()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        bindIfNeeded()
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        updateMaskImageIfNeeded()
        bindIfNeeded()
        updateBlurVisibility()
    }

    func dismantle() {
        clearObservers()
        observedScrollView = nil
    }

    private func clearObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func bindIfNeeded() {
        guard window != nil else { return }
        guard let target = findTargetScrollView() else { return }
        guard target !== observedScrollView else { return }
        clearObservers()
        observedScrollView = target
        target.contentView.postsBoundsChangedNotifications = true
        target.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: target.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateBlurVisibility() }
        })
        observers.append(center.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: target,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateBlurVisibility() }
        })
    }

    private func findTargetScrollView() -> NSScrollView? {
        var node: NSView? = superview
        while let current = node {
            if let found = Self.firstScrollView(in: current, excluding: self) {
                return found
            }
            if current === window?.contentView { break }
            node = current.superview
        }
        return nil
    }

    private static func firstScrollView(in root: NSView, excluding skipped: NSView) -> NSScrollView? {
        guard root !== skipped else { return nil }
        if let scroll = root as? NSScrollView { return scroll }
        for child in root.subviews {
            if let found = firstScrollView(in: child, excluding: skipped) {
                return found
            }
        }
        return nil
    }

    private func updateBlurVisibility() {
        guard let scroll = observedScrollView, let doc = scroll.documentView else {
            effectView.alphaValue = 0
            return
        }
        let visible = scroll.documentVisibleRect
        let overflowing = doc.bounds.height > visible.height + 4
        let scrolled = visible.minY
        if overflowing && scrolled > 1.5 {
            effectView.alphaValue = min(max((scrolled - 1.5) / 14.0, 0), 1.0)
        } else {
            effectView.alphaValue = 0
        }
    }

    private func updateMaskImageIfNeeded() {
        let size = bounds.size
        guard size.width > 1, size.height > 1, size != lastMaskSize else { return }
        lastMaskSize = size
        effectView.maskImage = Self.makeVerticalMask(size: size)
    }

    private static func makeVerticalMask(size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let gradient = NSGradient(colorsAndLocations:
                (NSColor.black.withAlphaComponent(1.0), 0.0),
                (NSColor.black.withAlphaComponent(0.75), 0.45),
                (NSColor.black.withAlphaComponent(0.0), 1.0)
            ) else { return false }
            // flipped: false 下 angle -90 表示从顶部 (1.0) 到底部 (0.0) 渐隐
            gradient.draw(in: rect, angle: -90)
            return true
        }
    }
}
