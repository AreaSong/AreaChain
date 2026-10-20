import AppKit
import Foundation

/// 错误只能展示通用恢复建议，不把可能含手记正文的底层错误描述复制到弹窗。
@MainActor
final class MutationFeedback {
    static let shared = MutationFeedback()
    private(set) var failureCount = 0
    /// 测试观察点：提示不在测试进程里弹出，只计数并记下最近一次的标签名。
    private(set) var skippedTagNoticeCount = 0
    private(set) var lastSkippedTags: [String] = []
    private var isPresenting = false

    func reportFailure(_ error: Error? = nil) {
        failureCount += 1
        let message: String
        if error is ModelRecoveryError { message = "save.rollback.failure" }
        else if error is AttachmentCleanupError { message = "attachment.cleanup.pending" }
        else { message = "save.failure.message" }
        present(title: "save.failure.title") { L10n.string(String.LocalizationValue(stringLiteral: message), locale: $0) }
    }

    func reportMemoryFallback() {
        present(title: "store.fallback.title") { L10n.string("store.fallback.message", locale: $0) }
    }

    /// 任务侧文字已保存，但其中的私密或预设标签没有关联；由 InputTagResolver 在保存成功后调用。
    func reportSkippedTags(_ names: [String]) {
        guard !names.isEmpty else { return }
        skippedTagNoticeCount += 1
        lastSkippedTags = names
        present(title: "tags.skipped.title", style: .informational) { locale in
            let list = ListFormatter()
            list.locale = locale
            let joined = list.string(from: names.map { "#" + $0 }) ?? names.joined(separator: ", ")
            return L10n.format("tags.skipped.message", locale: locale, joined)
        }
    }

    private func present(title: String, style: NSAlert.Style = .warning, message: @escaping (Locale) -> String) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !isPresenting else { return }
        isPresenting = true
        DispatchQueue.main.async {
            let locale = AppPreferences.shared.resolvedLocale
            let alert = NSAlert()
            alert.alertStyle = style
            alert.messageText = L10n.string(String.LocalizationValue(stringLiteral: title), locale: locale)
            alert.informativeText = message(locale)
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
