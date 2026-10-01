import Foundation

/// 无文本位置的语义项。页面条件不能借用用户 source 的位置。
struct ContentQuerySemanticTerm: Equatable {
    let atom: ContentQueryAtom
    var excluded = false

    init(atom: ContentQueryAtom, excluded: Bool = false) {
        self.atom = atom
        self.excluded = excluded
    }

    init(_ term: ContentQueryTerm) {
        self.init(atom: term.atom, excluded: term.excluded)
    }
}

enum ContentQueryConditionDimension: Hashable {
    case scope, content(ContentQueryDimension), sourceApplication, itemKind, todoStatus, routineStatus, contentTypes
}

/// 这些谓词只声明既有页面规则，未增加文本语法或实现真实查询。
enum ContentQueryPagePredicate: Equatable {
    case tagID(UUID, matching: ContentQueryTagMatching = .own)
    case noTags
    case sourceApplication(String)
    case reminderPresence(ReminderFilterScope)
    case boardDate(DateFilterScope, ContentQueryPageDateRule)
    case itemKind(ItemKindScope)
    case todoStatus(TodoStatusScope)
    case routineStatus(RoutineStatusScope)
    case contentTypes(Set<CommandObjectType>)

    var dimension: ContentQueryConditionDimension {
        switch self {
        case .tagID, .noTags: .content(.tag)
        case .sourceApplication: .sourceApplication
        case .reminderPresence: .content(.reminder)
        case .boardDate: .content(.date)
        case .itemKind: .itemKind
        case .todoStatus: .todoStatus
        case .routineStatus: .routineStatus
        case .contentTypes: .contentTypes
        }
    }
}

enum ContentQueryTagMatching: Equatable {
    case own
    /// ItemsListing 的父任务可因子任务标签入围；不等同统一文本标签的 ownTags。
    case taskOrSubtask
}

struct ContentQueryPageDateRule: Equatable {
    enum Evaluation: Equatable { case listedDay, agenda, items }
    let evaluation: Evaluation
    let todayKey: String
    let calendar: Calendar
}

enum ContentQueryConditionValue: Equatable {
    case scope(ContentQueryScopeSelection)
    case clause([ContentQuerySemanticTerm])
    case page(ContentQueryPagePredicate)

    static func atom(_ atom: ContentQueryAtom) -> Self { .clause([.init(atom: atom)]) }

    var dimension: ContentQueryConditionDimension? {
        switch self {
        case .scope: .scope
        case .clause(let terms): terms.first.map { .content($0.atom.dimension) }
        case .page(let predicate): predicate.dimension
        }
    }
}

struct ContentQueryConditionID: Hashable { let rawValue: Int }

enum ContentQueryConditionOrigin: Equatable {
    case page(visitID: String)
    case input(range: NSRange)
    case user

    var isPage: Bool {
        if case .page = self { return true }
        return false
    }
}

struct ContentQueryCondition: Equatable, Identifiable {
    let id: ContentQueryConditionID
    var value: ContentQueryConditionValue
    var origin: ContentQueryConditionOrigin
}

/// 诊断锚定语义条件身份；文本诊断仍由 ContentQuery 原样提供。
struct ContentQueryConditionDiagnostic: Equatable {
    let issue: ContentQueryIssue
    let conditionIDs: [ContentQueryConditionID]
}
