import SwiftUI

enum DaybookTitleStyle {
    case page
    case entity
}

struct DaybookPage<Trailing: View, Content: View>: View {
    var title: LocalizedStringKey?
    var titleText: String?
    var titleStyle: DaybookTitleStyle
    var systemImage: String?
    var subtitle: LocalizedStringKey?
    var subtitleText: String?
    var minWidth: CGFloat
    var minHeight: CGFloat
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
        self.trailing = trailing()
        self.content = content()
    }

    private var showsHeader: Bool {
        title != nil || titleText != nil || subtitle != nil || subtitleText != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            if showsHeader {
                HStack(alignment: .bottom, spacing: DaybookSpacing.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        titleLabel
                        subtitleLabel
                    }
                    Spacer(minLength: 0)
                    trailing
                }
            }
            content
        }
        .padding(DaybookSpacing.page)
        .frame(
            minWidth: minWidth,
            maxWidth: .infinity,
            minHeight: minHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(DaybookTheme.paper.opacity(0.94))
    }

    @ViewBuilder
    private var titleLabel: some View {
        if titleText != nil || title != nil {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(titleFont)
                        .foregroundStyle(DaybookTheme.stamp)
                }
                if let titleText {
                    Text(titleText)
                        .font(titleFont)
                        .foregroundStyle(DaybookTheme.ink)
                } else if let title {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(DaybookTheme.ink)
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleLabel: some View {
        if let subtitleText {
            Text(subtitleText)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
        } else if let subtitle {
            Text(subtitle)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
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
            trailing: { EmptyView() },
            content: content
        )
    }
}

struct DaybookComposer<Accessory: View>: View {
    @Binding var text: String
    var placeholder: String
    var focus: FocusState<Bool>.Binding?
    var availableTags: [String] = []
    var allowsShiftNewline: Bool
    var onSubmit: () -> Void
    var onCommandReturn: (() -> Void)?
    var accessory: Accessory

    @FocusState private var fallbackFocus: Bool
    @State private var autocomplete = SyntaxAutocompleteState()

    init(
        text: Binding<String>,
        placeholder: String,
        focus: FocusState<Bool>.Binding? = nil,
        availableTags: [String] = [],
        allowsShiftNewline: Bool = false,
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
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(isFocused ? DaybookTheme.stamp : DaybookTheme.muted)

                field

                ComposerAddButton(enabled: canSubmit, action: onSubmit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(isFocused ? DaybookTheme.surface : DaybookTheme.hoverFill.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(
                        isFocused ? DaybookTheme.focusRing : DaybookTheme.cardBorder,
                        lineWidth: isFocused ? 1.4 : 0.8
                    )
            )

            ZStack(alignment: .topLeading) {
                accessory
                if autocomplete.isActive {
                    SyntaxAutocompletePopup(state: autocomplete) { candidate in
                        if let trigger = autocomplete.trigger {
                            let (newText, _) = SyntaxAutocompleteEngine.applyCandidate(
                                candidate,
                                to: text,
                                range: trigger.range
                            )
                            text = newText
                            autocomplete.dismiss()
                        }
                    }
                    .padding(.top, 4)
                    .zIndex(100)
                }
            }
        }
        .daybookHideInputChrome()
    }

    @ViewBuilder
    private var field: some View {
        DaybookTextField(
            text: $text,
            placeholder: placeholder,
            focus: focus ?? $fallbackFocus,
            autocomplete: autocomplete,
            availableTags: availableTags,
            onSubmit: onSubmit,
            onCommandReturn: onCommandReturn,
            allowsShiftNewline: allowsShiftNewline
        )
    }
}

struct CaptureTokenBar: View {
    var text: String
    @Environment(\.locale) private var locale

    var body: some View {
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        Group {
            if parsed.hasTokens && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    if let time = parsed.timeLabel {
                        PillBadge(
                            title: L10n.format("workspace.remind.suffix", locale: locale, time),
                            icon: "clock.fill",
                            color: DaybookTheme.stamp,
                            isSelected: true
                        )
                    }
                    if let tag = parsed.tagName {
                        PillBadge(
                            title: "#\(tag)",
                            icon: "tag.fill",
                            color: Color(nsColor: .systemIndigo),
                            isSelected: true
                        )
                    }
                    if let priority = parsed.priorityLabel {
                        PillBadge(
                            title: L10n.string(String.LocalizationValue(stringLiteral: priority), locale: locale),
                            icon: "exclamationmark.circle.fill",
                            color: parsed.isImportant && parsed.isUrgent ? DaybookTheme.destructive : DaybookTheme.stamp,
                            isSelected: true
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

extension DaybookComposer where Accessory == EmptyView {
    init(
        text: Binding<String>,
        placeholder: String,
        focus: FocusState<Bool>.Binding? = nil,
        availableTags: [String] = [],
        allowsShiftNewline: Bool = false,
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
