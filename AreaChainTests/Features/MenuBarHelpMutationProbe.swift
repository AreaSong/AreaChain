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

/// 收尾批 M-7：搜索文字在统一搜索控制器的缓冲里，缓冲可能因发布结果被整体重写；这里只在文字值真正变化时计数，
/// 保持旧用例“搜索文字恰好写一次”的精度。观察回调在变化前触发，所以下一轮主线程再读新值。
@MainActor
final class ObservedTextChanges {
    private(set) var changes = 0
    private var last: String
    private let read: () -> String

    init(_ read: @escaping () -> String) {
        self.read = read
        last = read()
        observe()
    }

    func reset() { changes = 0; last = read() }

    private func observe() {
        withObservationTracking { _ = read() } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let current = self.read()
                    if current != self.last { self.changes += 1; self.last = current }
                    self.observe()
                }
            }
        }
    }
}
