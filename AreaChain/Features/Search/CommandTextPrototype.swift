#if AREACHAIN_QA
import AppKit
import SwiftUI

/// 只有这两种显式 QA 排版原型；环境缺省 nil，正式参数入口不切换引擎或装配时序。
enum CommandTextPrototype: String, CaseIterable {
    case viewport
    case textKit2

    @MainActor func system() -> CommandTextSystem {
        precondition(AppStartup.requireAllowed() == .testing)
        return self == .textKit2 ? .textKit2() : .legacy()
    }
}

private struct CommandTextPrototypeKey: EnvironmentKey {
    static let defaultValue: CommandTextPrototype? = nil
}

extension EnvironmentValues {
    var commandTextPrototype: CommandTextPrototype? {
        get { self[CommandTextPrototypeKey.self] }
        set { self[CommandTextPrototypeKey.self] = newValue }
    }
}

/// 只在真实非零视口宽度稳定后消费原一次性 access；没有额外正文缓存或续租。
@MainActor final class CommandTextPrototypeScrollView: NSScrollView {
    var attachOnce: (() -> Void)?
    private var scheduled = false
    private(set) var widthChanges = 0
    private var lastWidth: CGFloat = 0
    private(set) var attachedWidth: CGFloat?
    private let assembledAt = ContinuousClock.now
    private(set) var sizeStabilizationMS: Double?

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }

    override func layout() {
        super.layout()
        guard window != nil, contentSize.width > 1 else { return }
        if contentSize.width != lastWidth {
            widthChanges += 1
            lastWidth = contentSize.width
        }
        guard attachOnce != nil, !scheduled else { return }
        scheduled = true
        let width = contentSize.width
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            guard self.window != nil, self.contentSize.width == width,
                  let editor = self.documentView as? CommandProtectedTextView else {
                self.needsLayout = true
                return
            }
            editor.setFrameSize(NSSize(width: width, height: max(self.contentSize.height, 1)))
            self.attachedWidth = width
            let elapsed = self.assembledAt.duration(to: .now).components
            self.sizeStabilizationMS = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
            let attach = self.attachOnce
            self.attachOnce = nil
            CommandTextTiming.measure("prototypeAttach") { attach?() }
        }
    }
}
#endif
