import SwiftData
import SwiftUI

enum DaybookTitleStyle {
    case page
    case entity
}

struct DaybookPage<Trailing: View, Content: View>: View {
    @Environment(\.daybookViewStyle) private var style
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
            if showsHeader {
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
            maxWidth: (style.isWorkspace && !fullWidth) ? WorkspaceStyle.maxContentWidth : .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(DaybookSpacing.page)
        // 独立页面的最小尺寸不能反向撑大工作台；嵌入时由三栏布局分配空间。
        .frame(
            minWidth: style.isWorkspace ? 0 : minWidth,
            maxWidth: .infinity,
            minHeight: style.isWorkspace ? 0 : minHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(style.pageBackground)
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
        case .entity: style.isWorkspace ? DaybookType.title : DaybookType.entity
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
            BoardCaptureRow(focused: isFocused, fill: .clear, stroke: .clear, paintsChrome: false) {
                Image(systemName: "plus")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(isFocused ? DaybookTheme.stamp : DaybookTheme.muted)
            } field: {
                field
            } trailing: {
                CaptureAttributesButton(text: text, knownTags: completionTags, state: autocomplete)
                ComposerAddButton(enabled: canSubmit, action: onSubmit)
            }
            .daybookInputChrome(focused: isFocused, kind: .composer)
            .syntaxSuggestions(autocomplete)
            accessory
        }
        .daybookHideInputChrome()
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
