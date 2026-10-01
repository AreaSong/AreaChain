import Foundation

/// 目录声明不是授权或执行器；稳定身份独立于可改名的路径和本地化文案。
struct CommandID: RawRepresentable, Hashable, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
}

enum CommandCategory: String, CaseIterable, Sendable {
    case group, scope, navigation, query, modification, systemAction, interaction
}

enum CommandSubmission: Equatable, Sendable {
    case browse, refineQuery, navigate, previewModification, separateInteraction
}

enum CommandObjectType: String, CaseIterable, Sendable {
    case todo, subtask, routine, routineOccurrence, diary, tag, image, clipboardEntry
    case diaryWindow, clipboardWindow, workspaceWindow, draft, calendarConflict, activity
}

enum CommandContentScope: String, CaseIterable, Sendable {
    case tasks, routines, subtasks, diaries, tags, images, clipboard, trash

    var inclusion: CommandScopeInclusion {
        switch self {
        case .clipboard, .trash: .explicitOnly
        case .tasks: .ordinaryContent
        default: .ordinaryContent
        }
    }
}

enum CommandScopeInclusion: Equatable, Sendable {
    case ordinaryContent, explicitOnly, unresolvedComposition
}

enum CommandAvailability: Equatable, Sendable {
    case declared
    case unresolved(reasonKey: String)
    case unavailable(reasonKey: String)
}

enum CommandCapabilityEvidence: Equatable, Sendable {
    case unverified, notImplemented
    case conditional(reasonKey: String)
    case verified(source: String)
}

enum CommandBatchCapability: Equatable, Sendable {
    case notApplicable, singleOnly, explicitMultiple, unresolved
}

enum CommandQueuePolicy: Equatable, Sendable {
    case excluded, eligibleAfterWiring
}

enum CommandInteractionRequirement: String, Hashable, Sendable {
    case independentConfirmation, authentication, freshAuthentication, secureInput
    case nativeFilePanel, nativeShortcutRecorder, systemPermission, externalApplication
    case verifiedBackup, unsavedChangesConfirmation
}

enum CommandHazard: String, Hashable, Sendable {
    case privacyConversion, permanentDeletion, backupRestore, lifecycle, externalEffect, dataImport
}

enum CommandExecutionBinding: Equatable, Sendable { case unwired }

/// 这里只记录将来预览必须具备的事实，不采集字段，也不加载用户记录。
enum CommandPreviewField: Hashable, Sendable {
    case parameter(CommandParameterID)
    case targetIdentity, currentValues, effect, concreteDate, fieldLoss, externalResult
}

struct CommandDescriptor: Identifiable, Equatable, Sendable {
    let id: CommandID
    var path: String
    var pathAliases: [String] = []
    var parentID: CommandID?
    var category: CommandCategory
    var coverage: [CommandCoverage] = []
    var parameters: [CommandParameter] = []
    var targetTypes: Set<CommandObjectType> = []
    var batch: CommandBatchCapability = .notApplicable
    var contentScope: CommandContentScope?
    var preview: [CommandPreviewField] = []
    var queue: CommandQueuePolicy = .excluded
    var interactions: Set<CommandInteractionRequirement> = []
    var hazards: Set<CommandHazard> = []
    var availability: CommandAvailability = .declared
    var retry: CommandCapabilityEvidence = .unverified
    var undo: CommandCapabilityEvidence = .unverified
    let execution: CommandExecutionBinding = .unwired

    var nameKey: String {
        id.rawValue == "setting.language" ? "settings.language" : "command.\(id.rawValue).name"
    }
    var summaryKey: String { "command.\(id.rawValue).summary" }
    var aliasKey: String { "command.\(id.rawValue).aliases" }

    func name(locale: Locale) -> String { L10n.format(nameKey, locale: locale) }
    func summary(locale: Locale) -> String { L10n.format(summaryKey, locale: locale) }
    func aliases(locale: Locale) -> [String] {
        L10n.format(aliasKey, locale: locale).split(separator: "|").map(String.init)
    }

    var submission: CommandSubmission {
        switch category {
        case .group: .browse
        case .scope, .query: .refineQuery
        case .navigation: .navigate
        case .modification: .previewModification
        case .systemAction, .interaction: .separateInteraction
        }
    }

    // 阶段 1A 故意没有 wired 分支，目录完整不意味着任意适配已接通。
    var isExecutable: Bool { false }
    var canEnterOrdinaryQueue: Bool { isExecutable && queue == .eligibleAfterWiring }
}
