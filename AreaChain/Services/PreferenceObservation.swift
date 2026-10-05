import Foundation

/// 真实消费者共用的偏好订阅边界；普通事件按实例/存储和字段筛选，旧事件保留原路径。
@MainActor
final class PreferenceObservation {
    enum GroupDelivery: Equatable {
        case refreshed(UUID, fields: Set<LocalPreferenceField>)
        case superseded(UUID)
    }

    enum Consumer {
        case windowChrome, statusItem, diaryWindow, calendar

        var fields: Set<LocalPreferenceField> {
            switch self {
            case .windowChrome, .statusItem: return [.language, .appearance]
            case .diaryWindow: return [.language]
            case .calendar: return []
            }
        }
    }

    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []
    private var active = true
    private var currentRecord: (() -> LocalPreferenceRecord?)?
    private(set) var lastGroupDelivery: GroupDelivery?

    convenience init(preferences: AppPreferences, consumer: Consumer, center: NotificationCenter = .default,
                     presentation: @escaping @MainActor () -> Void, legacy: @escaping @MainActor () -> Void) {
        self.init(source: preferences.localPreferenceSource, consumer: consumer, center: center,
                  presentation: presentation, legacy: legacy)
        currentRecord = { [weak preferences] in preferences?.committedLocalPreferenceRecord }
    }

    init(source: LocalPreferenceSource, consumer: Consumer, center: NotificationCenter = .default,
         presentation: @escaping @MainActor () -> Void, legacy: @escaping @MainActor () -> Void) {
        self.center = center
        tokens.append(center.addObserver(forName: .appPreferencesDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard self?.active == true else { return }
                legacy()
            }
        })
        let fields = consumer.fields
        guard !fields.isEmpty else { return }
        tokens.append(center.addObserver(forName: .localPreferenceDidChange, object: nil, queue: .main) { [weak self] note in
            if let change = note.object as? LocalPreferenceGroupChange {
                guard change.source == source, !fields.isDisjoint(with: change.fields) else { return }
                Task { @MainActor in
                    guard let self, self.active else { return }
                    let currentFields = change.currentFields(in: self.currentRecord?()).intersection(fields)
                    guard !currentFields.isEmpty else {
                        self.lastGroupDelivery = .superseded(change.commitID)
                        return
                    }
                    self.lastGroupDelivery = .refreshed(change.commitID, fields: currentFields)
                    presentation()
                }
                return
            }
            guard let change = note.object as? LocalPreferenceChange, change.source == source,
                  fields.contains(change.field) else { return }
            Task { @MainActor in
                guard self?.active == true else { return }
                presentation()
            }
        })
    }

    func cancel() {
        active = false
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
    }

    deinit { tokens.forEach { center.removeObserver($0) } }
}
