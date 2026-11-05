import AppKit
import Foundation
import SwiftData

typealias ActionResult = ActionExecutionOutput

extension ActionHistoryStore {
    @discardableResult
    func undoLast(isVaultUnlocked: Bool = true) throws -> ActionDiff {
        try undo(isVaultUnlocked: isVaultUnlocked)
    }

    @discardableResult
    func redoLast(isVaultUnlocked: Bool = true) throws -> ActionDiff {
        try redo(isVaultUnlocked: isVaultUnlocked)
    }
}

/// 窗口控制、17 个工作台页面导航与全局历史动作集合。
@MainActor
enum WindowAndNavActions {
    static func all(history: ActionHistoryStore? = nil) -> [BaseAction] {
        let targetHistory = history ?? .shared
        return [
            UndoAction(historyStore: targetHistory),
            RedoAction(historyStore: targetHistory),
            HistoryQueryAction(historyStore: targetHistory),
            WindowOpenAction(),
            WindowCloseAction(),
            WindowPinAction(pin: true),
            WindowPinAction(pin: false),
            WindowResizeAction(),
            WindowCenterAction(),
        ] + navigationSpecs.map(WorkspaceTabNavigateAction.init) + [
            InspectorToggleAction(),
            MenuBarOverlayToggleAction(),
            AppQuitAction(),
        ]
    }

    fileprivate struct TabSpec {
        let id: ActionID
        let tab: WorkspaceTab
        let englishTitle: String
        let chineseTitle: String
        let aliases: [String]
    }

    private static let navigationSpecs: [TabSpec] = [
        .init(id: "go.dashboard", tab: .dashboard, englishTitle: "Go to Dashboard", chineseTitle: "前往总览看板", aliases: ["dashboard", "看板", "总览"]),
        .init(id: "go.today", tab: .today, englishTitle: "Go to Today", chineseTitle: "前往今日待办", aliases: ["today", "今日", "今天"]),
        .init(id: "go.pending", tab: .pending, englishTitle: "Go to Pending", chineseTitle: "前往待处理", aliases: ["pending", "待处理"]),
        .init(id: "go.allItems", tab: .allItems, englishTitle: "Go to All Items", chineseTitle: "前往全部事项", aliases: ["all", "all-items", "全部事项"]),
        .init(id: "go.calendar", tab: .calendar, englishTitle: "Go to Calendar", chineseTitle: "前往日历", aliases: ["cal", "calendar", "日历"]),
        .init(id: "go.quadrant", tab: .quadrant, englishTitle: "Go to Quadrant", chineseTitle: "前往四象限", aliases: ["quad", "quadrant", "四象限"]),
        .init(id: "go.gantt", tab: .gantt, englishTitle: "Go to Gantt", chineseTitle: "前往甘特图", aliases: ["gantt", "甘特图"]),
        .init(id: "go.diary", tab: .diary, englishTitle: "Go to Diary", chineseTitle: "前往手记页", aliases: ["diary-page", "notes-page", "手记页"]),
        .init(
            id: "go.attachments", tab: .attachments,
            englishTitle: "Go to Attachments", chineseTitle: "前往附件库",
            aliases: ["files", "attachments", "附件", "图片库"]
        ),
        .init(id: "go.clipboard", tab: .clipboard, englishTitle: "Go to Clipboard", chineseTitle: "前往剪贴板页", aliases: ["clip-page", "剪贴板页"]),
        .init(id: "go.tags", tab: .tags, englishTitle: "Go to Tags", chineseTitle: "前往标签页", aliases: ["tags-page", "标签页"]),
        .init(id: "go.privacy", tab: .privacy, englishTitle: "Go to Privacy", chineseTitle: "前往隐私页", aliases: ["privacy-page", "隐私页"]),
        .init(id: "go.dataBackup", tab: .dataBackup, englishTitle: "Go to Data Backup", chineseTitle: "前往数据备份页", aliases: ["backup-page", "数据备份页"]),
        .init(id: "go.trash", tab: .trash, englishTitle: "Go to Trash", chineseTitle: "前往回收站", aliases: ["trash-page", "回收站"]),
        .init(id: "go.settings", tab: .settings, englishTitle: "Go to Settings", chineseTitle: "前往设置", aliases: ["settings", "prefs", "设置"]),
        .init(id: "go.shortcuts", tab: .shortcuts, englishTitle: "Go to Shortcuts", chineseTitle: "前往快捷键说明", aliases: ["keys", "shortcuts", "快捷键"]),
        .init(id: "go.searchGuide", tab: .searchGuide, englishTitle: "Go to Search Guide", chineseTitle: "前往搜索指南", aliases: ["guide", "help", "搜索指南", "命令指南"]),
    ]

    fileprivate static func resolveTargetWindows(arguments: ParsedActionArguments, context: ActionContext) -> [BaseWindow] {
        let registry = WindowRegistry.shared
        if arguments.hasFlag("all") { return registry.windows }
        let target = arguments.targetQuery ?? arguments.option("target") ?? arguments.positional.first ?? context.activeWindowID
        return registry.resolveWindows(target: target)
    }
}

@MainActor
private final class WindowOpenAction: BaseAction {
    init() {
        super.init(
            id: "win.open", englishTitle: "Open Window", chineseTitle: "打开窗口",
            commandNames: ["win-open", "open-win", "打开窗口"], iconName: "macwindow.badge.plus", category: .window,
            parameters: [
                ActionParameterSpec(
                    id: "type", englishName: "Window Type", chineseName: "窗口类型",
                    defaultValue: "workspace", allowedValues: ["workspace", "clipboard", "quick", "preview"]
                ),
            ],
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let rawType = (arguments.value(for: "type", index: 0, defaultValue: "workspace") ?? "workspace").lowercased()
        switch rawType {
        case "workspace", "main", "工作台":
            if let win = WindowRegistry.shared.findWindow(category: "workspace") { win.openWindow() }
            else if AppWindows.workspaceViewProvider != nil { AppWindows.revealWorkspace() }
            return ActionExecutionOutput(message: "已打开工作台窗口")
        case "clipboard", "clip", "剪贴板":
            if let win = WindowRegistry.shared.findWindow(category: "clipboard") { win.openWindow() }
            else if !ClipboardHistoryPanel.shared.window.isVisible() { ClipboardHistoryPanel.shared.toggle() }
            return ActionExecutionOutput(message: "已打开剪贴板窗口")
        case "quick", "速记":
            if let win = WindowRegistry.shared.findWindow(category: "quick") { win.openWindow() }
            else { QuickEntryPanelController.shared.show() }
            return ActionExecutionOutput(message: "已打开极速速记窗口")
        case "preview", "预览":
            if let win = WindowRegistry.shared.findWindow(category: "preview") { win.openWindow() }
            else {
                AppWindows.openControlsPreview(
                    localeID: AppPreferences.shared.resolvedLocale.identifier,
                    dark: AppPreferences.shared.appearance == .dark
                )
            }
            return ActionExecutionOutput(message: "已打开控件预览窗口")
        default:
            if let matched = WindowRegistry.shared.findWindow(target: rawType) {
                matched.openWindow()
                return ActionExecutionOutput(message: "已打开窗口：\(matched.windowTitle)")
            }
            throw ActionExecutionError.invalidParameterValue(parameter: "type", value: rawType)
        }
    }
}

@MainActor
private final class WindowCloseAction: BaseAction {
    init() {
        super.init(
            id: "win.close", englishTitle: "Close Window", chineseTitle: "关闭窗口",
            commandNames: ["win-close", "close-win", "close", "wclose", "关闭窗口"], iconName: "xmark.square", category: .window,
            parameters: [ActionParameterSpec(id: "target", englishName: "Window", chineseName: "目标窗口")],
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let targets = WindowAndNavActions.resolveTargetWindows(arguments: arguments, context: context)
        guard !targets.isEmpty else { return ActionExecutionOutput(message: "当前没有打开的匹配窗口") }
        let force = context.confirmed || arguments.hasFlag("force") || arguments.hasFlag("confirm")
        var closedCount = 0
        var blockedTitles: [String] = []
        for window in targets {
            if !force && window.hasUnsavedChanges() {
                if window.closeWindow(force: false) { closedCount += 1 }
                else { blockedTitles.append(window.windowTitle.isEmpty ? window.windowID : window.windowTitle) }
            } else if window.closeWindow(force: force) {
                closedCount += 1
            }
        }
        if !blockedTitles.isEmpty {
            return ActionExecutionOutput(message: "窗口含未保存修改，已请求确认：\(blockedTitles.joined(separator: "、"))")
        }
        return ActionExecutionOutput(message: "已关闭 \(closedCount) 个窗口")
    }
}

@MainActor
private final class WindowPinAction: BaseAction {
    private let pin: Bool

    init(pin: Bool) {
        self.pin = pin
        super.init(
            id: pin ? "win.pin" : "win.unpin",
            englishTitle: pin ? "Pin Window on Top" : "Unpin Window",
            chineseTitle: pin ? "窗口置顶" : "取消窗口置顶",
            commandNames: pin ? ["win-pin", "pin", "top", "置顶", "置顶窗口"] : ["win-unpin", "unpin", "untop", "取消置顶"],
            iconName: pin ? "pin.fill" : "pin.slash", category: .window,
            parameters: [ActionParameterSpec(id: "target", englishName: "Window", chineseName: "目标窗口")],
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        guard let target = WindowAndNavActions.resolveTargetWindows(arguments: arguments, context: context).first else {
            throw ActionExecutionError.targetNotFound("当前无可用窗口")
        }
        guard target.supportsPinning else { throw ActionExecutionError.unavailable("该窗口不支持置顶") }
        target.setPinned(pin)
        let label = target.windowTitle.isEmpty ? target.windowID : target.windowTitle
        return ActionExecutionOutput(message: "\(pin ? "已置顶" : "已取消置顶")窗口：\(label)")
    }
}

@MainActor
private final class WindowResizeAction: BaseAction {
    init() {
        super.init(
            id: "win.resize", englishTitle: "Resize Window", chineseTitle: "调整窗口尺寸",
            commandNames: ["win-size", "resize", "size", "窗口尺寸", "窗口大小"], iconName: "arrow.up.left.and.arrow.down.right", category: .window,
            parameters: [
                ActionParameterSpec(
                    id: "preset", englishName: "Preset or WxH", chineseName: "预设或宽高",
                    defaultValue: "standard", allowedValues: ["compact", "standard", "expanded", "wide", "tall"]
                ),
            ],
            recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let token = (arguments.value(for: "preset", index: 0, defaultValue: "standard") ?? "standard").lowercased()
        let size = try Self.parseSize(token)
        if let target = WindowAndNavActions.resolveTargetWindows(arguments: arguments, context: context).first {
            target.resize(width: size.width, height: size.height)
        } else if let wsWindow = PanelWindowController.workspace.hostedWindow {
            wsWindow.setContentSize(size)
        }
        return ActionExecutionOutput(message: "窗口尺寸已设为 \(Int(size.width))×\(Int(size.height))")
    }

    private static func parseSize(_ token: String) throws -> NSSize {
        switch token {
        case "compact", "紧凑": return NSSize(width: 900, height: 620)
        case "standard", "标准": return NSSize(width: 1120, height: 740)
        case "wide", "expanded", "宽屏", "展开": return NSSize(width: 1360, height: 800)
        case "tall", "修长": return NSSize(width: 1000, height: 920)
        default:
            let parts = token.replacingOccurrences(of: "*", with: "x").split(separator: "x")
            if parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]), w >= 240, h >= 180 {
                return NSSize(width: w, height: h)
            }
            throw ActionExecutionError.invalidParameterValue(parameter: "preset", value: token)
        }
    }
}

@MainActor
private final class WindowCenterAction: BaseAction {
    init() {
        super.init(
            id: "win.center", englishTitle: "Center Window", chineseTitle: "窗口居中",
            commandNames: ["win-center", "center", "窗口居中"], iconName: "viewfinder", category: .window, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        if let target = WindowAndNavActions.resolveTargetWindows(arguments: arguments, context: context).first {
            target.centerOnActiveScreen()
        } else if let wsWindow = PanelWindowController.workspace.hostedWindow {
            AppWindows.centerWindow(wsWindow)
        }
        return ActionExecutionOutput(message: "已将窗口居中")
    }
}

@MainActor
private final class WorkspaceTabNavigateAction: BaseAction {
    private let tab: WorkspaceTab

    init(_ spec: WindowAndNavActions.TabSpec) {
        self.tab = spec.tab
        super.init(
            id: spec.id, englishTitle: spec.englishTitle, chineseTitle: spec.chineseTitle,
            commandNames: spec.aliases, iconName: spec.tab.iconName, category: .navigation, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        WorkspaceNavigation.shared.revealTab(tab)
        if AppWindows.workspaceViewProvider != nil {
            AppWindows.openWorkspace(tab: tab)
        }
        return ActionExecutionOutput(message: "已切换到：\(chineseTitle)")
    }
}

@MainActor
private final class InspectorToggleAction: BaseAction {
    init() {
        super.init(
            id: "ui.inspector", englishTitle: "Toggle Inspector Drawer", chineseTitle: "切换详情栏",
            commandNames: ["inspector", "drawer", "详情栏"], iconName: "sidebar.right", category: .window, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        let nav = WorkspaceNavigation.shared
        let mode = arguments.positional.first?.lowercased()
        if mode == "on" || mode == "open" || mode == "打开" { nav.isInspectorPresented = true }
        else if mode == "off" || mode == "close" || mode == "关闭" { nav.closeInspector() }
        else { nav.isInspectorPresented.toggle() }
        return ActionExecutionOutput(message: nav.isInspectorPresented ? "已展开详情栏" : "已收起详情栏")
    }
}

@MainActor
private final class MenuBarOverlayToggleAction: BaseAction {
    init() {
        super.init(
            id: "ui.overlay", englishTitle: "Toggle Menu Bar Popover", chineseTitle: "切换菜单栏浮层",
            commandNames: ["menubar", "popover", "菜单栏浮层"], iconName: "menubar.rectangle", category: .window, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        StatusItemController.shared.toggle()
        return ActionExecutionOutput(message: "已切换菜单栏浮层")
    }
}

@MainActor
private final class AppQuitAction: BaseAction {
    init() {
        super.init(
            id: "app.quit", englishTitle: "Quit Application", chineseTitle: "退出应用",
            commandNames: ["quit", "exit", "退出"], iconName: "power", category: .window,
            permissionLevel: .system, riskLevel: .confirm, recordsUndo: false
        )
    }

    override func perform(arguments: ParsedActionArguments, context: ActionContext) throws -> ActionExecutionOutput {
        if AppStartup.policy != .testing { NSApp.terminate(nil) }
        return ActionExecutionOutput(message: "正在退出应用")
    }
}
