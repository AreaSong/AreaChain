import Foundation
import Observation

/// 任务捕获和手记快速输入共用的草稿。任务只用正文；手记另外带标签选择和锁定封存。
struct BoardComposerDraft {
    var id = UUID()
    var text = ""
    var selectedTagIDs: Set<UUID> = []
    var needsProtection = false
    var sealed: SealedDiaryDraft?

    var hasContent: Bool { sealed != nil || !text.isEmpty }

    @MainActor mutating func seal(vault: PrivacyVault) throws {
        guard needsProtection, sealed == nil, vault.isUnlocked else { return }
        sealed = try SealedDiaryDraft.seal(text: text, baseline: "", id: id, vault: vault)
        text = ""
    }

    @MainActor mutating func restore(vault: PrivacyVault) throws {
        guard let sealed, vault.isUnlocked else { return }
        text = try sealed.open(vault: vault).text
        self.sealed = nil
    }
}

/// 菜单栏和工作台今日、手记页共用的筛选。标签、优先级、提醒和来源写入偏好；日期范围只留在本次运行。
@Observable @MainActor
final class BoardFilterSession {
    static let shared: BoardFilterSession = {
        let session = BoardFilterSession(filters: AppPreferences.shared.storedBoardFilters())
        session.onChange = { AppPreferences.shared.storeBoardFilters($0) }
        return session
    }()

    var onChange: ((BoardFilters) -> Void)?
    var filters = BoardFilters() {
        didSet {
            guard filters != oldValue else { return }
            onChange?(filters)
        }
    }

    init(filters: BoardFilters = BoardFilters()) {
        self.filters = filters
    }

    /// 工作台顶部搜索使用任务筛选，与菜单栏任务页同一份。
    var globalSearchFilter: BoardFilter { filters.tasks }
}

/// 本次运行里的任务草稿和手记草稿。收起菜单栏不丢弃，也不写入偏好。锁定只封存手记草稿。
@Observable @MainActor
final class BoardComposerSession {
    static let shared = BoardComposerSession()
    var tasks = BoardComposerDraft()
    var diary = BoardComposerDraft()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(vault: PrivacyVault? = nil) {
        let vault = vault ?? .shared
        observers.append(NotificationCenter.default.addObserver(forName: .privacyWillLock, object: vault, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                var diary = self.diary
                try? diary.seal(vault: vault)
                self.diary = diary
            }
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
