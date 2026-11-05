import Foundation

/// 统一动作的稳定唯一标识符，供注册表索引、历史记录与外部自动化调用共用。
struct ActionID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    var description: String { rawValue }

    static func < (lhs: ActionID, rhs: ActionID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static let undo: ActionID = "history.undo"
    static let redo: ActionID = "history.redo"
    static let historyQuery: ActionID = "history.query"
}

/// 动作所属的业务功能分组，用于自动生成指令目录与说明页。
enum ActionCategory: String, CaseIterable, Hashable, Codable, Sendable {
    case window
    case navigation
    case task
    case routine
    case subtask
    case planning
    case diary
    case tag
    case attachment
    case clipboard
    case settings
    case privacy
    case backup
    case trash
    case history

    var titleKey: String {
        "action.category.\(rawValue)"
    }

    var englishTitle: String {
        switch self {
        case .window: return "Window"
        case .navigation: return "Navigation"
        case .task: return "Tasks"
        case .routine: return "Routines"
        case .subtask: return "Subtasks"
        case .planning: return "Planning"
        case .diary: return "Diary"
        case .tag: return "Tags"
        case .attachment: return "Attachments"
        case .clipboard: return "Clipboard"
        case .settings: return "Settings"
        case .privacy: return "Privacy"
        case .backup: return "Backup"
        case .trash: return "Trash"
        case .history: return "History"
        }
    }

    var chineseTitle: String {
        switch self {
        case .window: return "窗口"
        case .navigation: return "导航"
        case .task: return "待办"
        case .routine: return "习惯"
        case .subtask: return "子任务"
        case .planning: return "规划"
        case .diary: return "手记"
        case .tag: return "标签"
        case .attachment: return "附件"
        case .clipboard: return "剪贴板"
        case .settings: return "设置"
        case .privacy: return "隐私"
        case .backup: return "备份与恢复"
        case .trash: return "回收站"
        case .history: return "历史与撤销"
        }
    }

    func localizedTitle(for locale: Locale) -> String {
        locale.identifier.hasPrefix("zh") ? chineseTitle : englishTitle
    }
}

/// 动作权限级别，约束外部自动化调用与隐私门禁的访问边界（普通 < 隐私 < 系统）。
enum ActionPermissionLevel: String, CaseIterable, Hashable, Codable, Sendable, Comparable {
    case normal
    case privacy
    case system

    private var rank: Int {
        switch self {
        case .normal: return 0
        case .privacy: return 1
        case .system: return 2
        }
    }

    static func < (lhs: ActionPermissionLevel, rhs: ActionPermissionLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var englishTitle: String {
        switch self {
        case .normal: return "Normal"
        case .privacy: return "Privacy"
        case .system: return "System"
        }
    }

    var chineseTitle: String {
        switch self {
        case .normal: return "普通"
        case .privacy: return "隐私"
        case .system: return "系统"
        }
    }
}

/// 动作执行的交互风险级别，决定直接执行、内联二次确认、系统身份认证或文件选择框。
enum ActionRiskLevel: String, CaseIterable, Hashable, Codable, Sendable {
    case direct
    case confirm
    case authentication
    case fileDialog
}

/// 动作参数的元数据声明，用于命令行校验、自动补全与帮助文档生成。
struct ActionParameterSpec: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nameKey: String
    let englishName: String
    let chineseName: String
    let required: Bool
    let defaultValue: String?
    let allowedValues: [String]

    init(
        id: String,
        nameKey: String? = nil,
        englishName: String,
        chineseName: String,
        required: Bool = false,
        defaultValue: String? = nil,
        allowedValues: [String] = []
    ) {
        self.id = id
        self.nameKey = nameKey ?? "action.param.\(id)"
        self.englishName = englishName
        self.chineseName = chineseName
        self.required = required
        self.defaultValue = defaultValue
        self.allowedValues = allowedValues
    }
}

/// 动作在当前宿主上下文中的可用性状态。
enum ActionAvailability: Equatable, Hashable, Codable, Sendable {
    case available
    case disabled(reason: String)
    case requiresUnlock

    var isAvailable: Bool {
        self == .available
    }
}

/// 单个字段修改前后的对比记录。
struct ActionFieldChange: Codable, Equatable, Hashable, Sendable {
    let field: String
    let before: String
    let after: String

    init(field: String, before: String, after: String) {
        self.field = field
        self.before = before
        self.after = after
    }

    var formattedChange: String {
        if before.isEmpty {
            return "\(field) → \(after)"
        }
        return "\(field) \(before) → \(after)"
    }
}

/// 单次动作产生的人类可读修改明细；当记录标记为敏感且私密锁未解开时隐藏明文。
struct ActionDiff: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let actionID: ActionID
    let actionTitle: String
    let targetTitle: String
    let timestamp: Date
    let changes: [ActionFieldChange]
    let isSensitive: Bool

    static let redactedPlaceholder = "私密操作（已锁定隐藏明细）"

    init(
        id: UUID = UUID(),
        actionID: ActionID,
        actionTitle: String,
        targetTitle: String,
        timestamp: Date = Date(),
        changes: [ActionFieldChange] = [],
        isSensitive: Bool = false
    ) {
        self.id = id
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.targetTitle = targetTitle
        self.timestamp = timestamp
        self.changes = changes
        self.isSensitive = isSensitive
    }

    var formattedSummary: String {
        formattedSummary(isVaultUnlocked: true)
    }

    func formattedSummary(isLocked: Bool) -> String {
        formattedSummary(isVaultUnlocked: !isLocked)
    }

    func formattedSummary(isVaultUnlocked: Bool) -> String {
        if isSensitive && !isVaultUnlocked {
            return Self.redactedPlaceholder
        }
        let changePart = changes.map(\.formattedChange).joined(separator: "，")
        let header = targetTitle.isEmpty ? actionTitle : targetTitle
        if changePart.isEmpty {
            if !targetTitle.isEmpty && targetTitle != actionTitle {
                return "\(actionTitle)：\(targetTitle)"
            }
            return header
        }
        return "\(header)：\(changePart)"
    }

    /// 锁定时对敏感明细屏蔽明文搜索，避免通过关键词探测私密内容。
    func matches(keyword: String, isVaultUnlocked: Bool = true) -> Bool {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if isSensitive && !isVaultUnlocked {
            return Self.redactedPlaceholder.localizedCaseInsensitiveContains(trimmed)
                || actionID.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
        if actionTitle.localizedCaseInsensitiveContains(trimmed)
            || targetTitle.localizedCaseInsensitiveContains(trimmed)
            || actionID.rawValue.localizedCaseInsensitiveContains(trimmed)
            || formattedSummary(isVaultUnlocked: true).localizedCaseInsensitiveContains(trimmed) {
            return true
        }
        return changes.contains { change in
            change.field.localizedCaseInsensitiveContains(trimmed)
                || change.before.localizedCaseInsensitiveContains(trimmed)
                || change.after.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

/// 动作执行时读取的宿主、窗口、页面选中项与权限快照。
struct ActionContext: Equatable, Hashable, Codable, Sendable {
    var instanceID: UUID = UUID()
    var host: String
    var activeWindowID: String?
    var currentTab: String?
    var selectedObjectIDs: [UUID]
    var focusedObjectID: UUID?
    var focusedObjectTitle: String?
    var todayKey: String
    var isVaultUnlocked: Bool
    var allowedExternalPermission: ActionPermissionLevel
    var confirmed: Bool

    init(
        host: String = "workspace",
        activeWindowID: String? = nil,
        currentTab: String? = nil,
        selectedObjectIDs: [UUID] = [],
        focusedObjectID: UUID? = nil,
        focusedObjectTitle: String? = nil,
        todayKey: String = DayKey.today(),
        isVaultUnlocked: Bool = false,
        allowedExternalPermission: ActionPermissionLevel = .system,
        confirmed: Bool = false
    ) {
        self.host = host
        self.activeWindowID = activeWindowID
        self.currentTab = currentTab
        self.selectedObjectIDs = selectedObjectIDs
        self.focusedObjectID = focusedObjectID
        self.focusedObjectTitle = focusedObjectTitle
        self.todayKey = todayKey
        self.isVaultUnlocked = isVaultUnlocked
        self.allowedExternalPermission = allowedExternalPermission
        self.confirmed = confirmed
    }
}

/// 跨重启持久化的动作撤销载荷，不保存明文长正文或密码凭据。
struct ActionUndoPayload: Codable, Equatable, Hashable, Sendable {
    let actionID: ActionID
    let targetIDs: [UUID]
    let snapshot: [String: String]

    init(actionID: ActionID, targetIDs: [UUID] = [], snapshot: [String: String] = [:]) {
        self.actionID = actionID
        self.targetIDs = targetIDs
        self.snapshot = snapshot
    }
}

/// 供命令解析器、自动补全与动作目录使用的纯值类型动作描述。
struct ActionMetadataDescriptor: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: ActionID
    let titleKey: String
    let englishTitle: String
    let chineseTitle: String
    let commandNames: [String]
    let iconName: String
    let category: ActionCategory
    let parameters: [ActionParameterSpec]
    let permissionLevel: ActionPermissionLevel
    let riskLevel: ActionRiskLevel
    let recordsUndo: Bool

    var primaryCommand: String {
        commandNames.first ?? id.rawValue
    }

    func localizedTitle(for locale: Locale = .current) -> String {
        locale.identifier.hasPrefix("zh") ? chineseTitle : englishTitle
    }
}

/// 按分组导出的动作目录分组项。
struct ActionCatalogGroup: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: ActionCategory { category }
    let category: ActionCategory
    let actions: [ActionMetadataDescriptor]
}
