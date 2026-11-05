import SwiftUI

/// 按钮语义角色，统一映射到 DaybookButtonVariant，禁止页面手写裸颜色或 .buttonStyle(.plain)。
enum DaybookButtonRole: Equatable {
    case quiet
    case subtle
    case prominent
    case primary
    case destructive
    case active
    case pill(tint: Color)
    case icon
    case iconActive
    case iconDestructive

    func variant(isIconOnly: Bool, isActive: Bool) -> DaybookButtonVariant {
        if isIconOnly {
            switch self {
            case .destructive, .iconDestructive:
                return .iconDestructive
            case .active, .iconActive, .prominent, .primary:
                return .iconActive
            default:
                return isActive ? .iconActive : .icon
            }
        }
        switch self {
        case .quiet:
            return isActive ? .active : .quiet
        case .subtle:
            return isActive ? .active : .subtle
        case .prominent, .primary:
            return .prominent
        case .destructive:
            return .destructive
        case .active:
            return .active
        case .pill(let tint):
            return .pill(tint: tint)
        case .icon:
            return isActive ? .iconActive : .icon
        case .iconActive:
            return .iconActive
        case .iconDestructive:
            return .iconDestructive
        }
    }

    var systemRole: ButtonRole? {
        switch self {
        case .destructive, .iconDestructive:
            return .destructive
        default:
            return nil
        }
    }
}

/// 控件统一尺寸梯度，映射 DaybookButtonSize 的命中区、内边距与圆角令牌。
enum DaybookControlSize: Equatable, Sendable {
    case regular
    case compact
    case inline

    var buttonSize: DaybookButtonSize {
        switch self {
        case .regular: return .regular
        case .compact: return .compact
        case .inline: return .inline
        }
    }

    var hit: CGFloat { buttonSize.hit }
    var radius: CGFloat { buttonSize.radius }
    var iconFont: Font { buttonSize.iconFont }
}

/// 统一动作按钮的分发与状态同步桥接器，支持直接回调或通过动作注册表按 actionID 触发。
@MainActor
final class DaybookActionDispatcher {
    static let shared = DaybookActionDispatcher()

    var fallbackExecutor: (@MainActor (String) -> Void)?
    var availabilityResolver: (@MainActor (String) -> (isEnabled: Bool, reason: String?))?
    var tooltipResolver: (@MainActor (String) -> String?)?
    private(set) var lastTriggeredActionID: String?
    private var handlers: [String: @MainActor () -> Void] = [:]

    func register(actionID: String, handler: @escaping @MainActor () -> Void) {
        handlers[actionID] = handler
    }

    func unregister(actionID: String) {
        handlers.removeValue(forKey: actionID)
    }

    func reset() {
        handlers.removeAll()
        fallbackExecutor = nil
        availabilityResolver = nil
        tooltipResolver = nil
        lastTriggeredActionID = nil
    }

    func isEnabled(for actionID: String, explicitEnabled: Bool) -> Bool {
        guard explicitEnabled, !actionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if let availabilityResolver {
            return availabilityResolver(actionID).isEnabled
        }
        return true
    }

    func resolvedTooltip(for actionID: String, explicitTooltip: String?) -> String? {
        if let availability = availabilityResolver?(actionID), !availability.isEnabled,
           let reason = availability.reason, !reason.isEmpty {
            return reason
        }
        if let explicitTooltip, !explicitTooltip.isEmpty {
            return explicitTooltip
        }
        if let reason = availabilityResolver?(actionID).reason, !reason.isEmpty {
            return reason
        }
        return tooltipResolver?(actionID)
    }

    func perform(actionID: String, explicitAction: (() -> Void)? = nil) {
        lastTriggeredActionID = actionID
        if let explicitAction {
            explicitAction()
        } else if let handler = handlers[actionID] {
            handler()
        } else {
            fallbackExecutor?(actionID)
        }
    }
}

/// 标准图文按钮标签，复用 DaybookType 与 DaybookSpacing 令牌。
struct DaybookActionButtonStandardLabel: View {
    let title: Text
    let systemImage: String?
    let size: DaybookControlSize

    var body: some View {
        HStack(spacing: DaybookSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(size.iconFont)
            }
            title
                .font(size == .inline ? DaybookType.caption : DaybookType.body)
                .lineLimit(1)
        }
    }
}

/// 纯图标按钮标签，复用 DaybookButtonSize 的图标字号令牌。
struct DaybookActionButtonIconLabel: View {
    let systemImage: String
    let size: DaybookControlSize

    var body: some View {
        Image(systemName: systemImage)
            .font(size.iconFont)
    }
}

/// 全软件可点击控件的唯一动作绑定基座：强制要求传入非空 actionID，统一接入 DaybookButtonStyle。
@MainActor
struct DaybookActionButton<Label: View>: View {
    let actionID: String
    var role: DaybookButtonRole
    var size: DaybookControlSize
    var isActive: Bool
    var isEnabled: Bool
    var isFocused: Bool
    var isIconOnly: Bool
    var tooltip: String?
    var accessibilityTitle: String?
    var dispatcher: DaybookActionDispatcher
    var action: (() -> Void)?
    @ViewBuilder var label: () -> Label

    init(
        actionID: String,
        role: DaybookButtonRole = .quiet,
        size: DaybookControlSize = .regular,
        isActive: Bool = false,
        isEnabled: Bool = true,
        isFocused: Bool = false,
        isIconOnly: Bool = false,
        tooltip: String? = nil,
        accessibilityTitle: String? = nil,
        dispatcher: DaybookActionDispatcher? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.actionID = actionID
        self.role = role
        self.size = size
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.isFocused = isFocused
        self.isIconOnly = isIconOnly
        self.tooltip = tooltip
        self.accessibilityTitle = accessibilityTitle
        self.dispatcher = dispatcher ?? .shared
        self.action = action
        self.label = label
    }

    var effectiveEnabled: Bool {
        dispatcher.isEnabled(for: actionID, explicitEnabled: isEnabled)
    }

    var effectiveTooltip: String? {
        dispatcher.resolvedTooltip(for: actionID, explicitTooltip: tooltip)
    }

    var resolvedVariant: DaybookButtonVariant {
        role.variant(isIconOnly: isIconOnly, isActive: isActive)
    }

    func trigger() {
        guard effectiveEnabled else { return }
        dispatcher.perform(actionID: actionID, explicitAction: action)
    }

    var body: some View {
        Button(role: role.systemRole, action: trigger) {
            label()
        }
        .buttonStyle(DaybookButtonStyle(resolvedVariant, size: size.buttonSize, isFocused: isFocused))
        .disabled(!effectiveEnabled)
        .accessibilityIdentifier(actionID)
        .accessibilityLabel(Text(verbatim: accessibilityTitle ?? effectiveTooltip ?? actionID))
        .help(effectiveTooltip ?? "")
    }
}

extension DaybookActionButton where Label == DaybookActionButtonStandardLabel {
    init(
        actionID: String,
        title: String,
        systemImage: String? = nil,
        role: DaybookButtonRole = .quiet,
        size: DaybookControlSize = .regular,
        isActive: Bool = false,
        isEnabled: Bool = true,
        tooltip: String? = nil,
        dispatcher: DaybookActionDispatcher? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            actionID: actionID, role: role, size: size, isActive: isActive,
            isEnabled: isEnabled, isIconOnly: false, tooltip: tooltip ?? title,
            accessibilityTitle: title, dispatcher: dispatcher, action: action
        ) {
            DaybookActionButtonStandardLabel(
                title: Text(verbatim: title), systemImage: systemImage, size: size
            )
        }
    }

    init(
        actionID: String,
        titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        role: DaybookButtonRole = .quiet,
        size: DaybookControlSize = .regular,
        isActive: Bool = false,
        isEnabled: Bool = true,
        tooltip: String? = nil,
        dispatcher: DaybookActionDispatcher? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            actionID: actionID, role: role, size: size, isActive: isActive,
            isEnabled: isEnabled, isIconOnly: false, tooltip: tooltip,
            accessibilityTitle: tooltip, dispatcher: dispatcher, action: action
        ) {
            DaybookActionButtonStandardLabel(
                title: Text(titleKey), systemImage: systemImage, size: size
            )
        }
    }
}

extension DaybookActionButton where Label == DaybookActionButtonIconLabel {
    init(
        actionID: String,
        systemImage: String,
        tooltip: String,
        role: DaybookButtonRole = .icon,
        size: DaybookControlSize = .regular,
        isActive: Bool = false,
        isEnabled: Bool = true,
        dispatcher: DaybookActionDispatcher? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            actionID: actionID, role: role, size: size, isActive: isActive,
            isEnabled: isEnabled, isIconOnly: true, tooltip: tooltip,
            accessibilityTitle: tooltip, dispatcher: dispatcher, action: action
        ) {
            DaybookActionButtonIconLabel(systemImage: systemImage, size: size)
        }
    }
}
