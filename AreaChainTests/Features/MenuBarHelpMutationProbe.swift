import Foundation
import Observation
import SwiftData

/// 观察真实草稿写入和保存通知；不包装或替换生产帮助回调。
@MainActor
final class MenuBarHelpMutationProbe {
    var writes = 0
    var saves = 0
    private let read: () -> Void
    private var saveObserver: NSObjectProtocol?

    init(context: ModelContext, read: @escaping () -> Void) {
        self.read = read
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.willSave,
            object: context, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saves += 1 }
            }
        observe()
    }

    private func observe() {
        withObservationTracking(read) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.writes += 1
                self.observe()
            }
        }
    }

    deinit {
        if let saveObserver { NotificationCenter.default.removeObserver(saveObserver) }
    }
}
