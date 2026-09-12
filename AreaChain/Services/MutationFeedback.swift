import AppKit
import Foundation

/// 错误只能展示通用恢复建议，不把可能含手记正文的底层错误描述复制到弹窗。
@MainActor
final class MutationFeedback {
    static let shared = MutationFeedback()
    private(set) var failureCount = 0
    private var isPresenting = false

    func reportFailure(_ error: Error? = nil) {
        failureCount += 1
        present(title: "save.failure.title", message: error is ModelRecoveryError ? "save.rollback.failure" : "save.failure.message")
    }

    func reportMemoryFallback() {
        present(title: "store.fallback.title", message: "store.fallback.message")
    }

    private func present(title: String, message: String) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !isPresenting else { return }
        isPresenting = true
        DispatchQueue.main.async {
            let locale = AppPreferences.shared.resolvedLocale
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.string(String.LocalizationValue(stringLiteral: title), locale: locale)
            alert.informativeText = L10n.string(String.LocalizationValue(stringLiteral: message), locale: locale)
            alert.addButton(withTitle: L10n.string("common.close", locale: locale))
            if let window = NSApp.keyWindow, window.attachedSheet == nil {
                alert.beginSheetModal(for: window) { _ in self.isPresenting = false }
            } else {
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                self.isPresenting = false
            }
        }
    }
}
