import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppTerminationTests {
    @Test(arguments: [NSApplication.ModalResponse.alertSecondButtonReturn, .abort, .stop])
    func cancellingQuitDoesNotStartDiarySaveOrDiscard(_ response: NSApplication.ModalResponse) {
        let delegate = AppDelegate()
        var events: [String] = []
        delegate.presentQuitConfirmation = { _ in events.append("quit"); return response }
        delegate.confirmDiaryTermination = { events.append("diary"); return true }

        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateCancel)
        #expect(events == ["quit"])
    }

    @Test(arguments: [true, false])
    func confirmedQuitStillRequiresDiaryApproval(_ diaryAllowsTermination: Bool) {
        let delegate = AppDelegate()
        var events: [String] = []
        delegate.presentQuitConfirmation = { _ in events.append("quit"); return .alertFirstButtonReturn }
        delegate.confirmDiaryTermination = { events.append("diary"); return diaryAllowsTermination }

        let expected: NSApplication.TerminateReply = diaryAllowsTermination ? .terminateNow : .terminateCancel
        #expect(delegate.applicationShouldTerminate(NSApp) == expected)
        #expect(events == ["quit", "diary"])
    }

    @Test func cancellationDoesNotSuppressTheNextConfirmation() {
        let delegate = AppDelegate()
        var prompts = 0
        delegate.presentQuitConfirmation = { _ in
            prompts += 1
            return prompts == 1 ? .alertSecondButtonReturn : .alertFirstButtonReturn
        }
        delegate.confirmDiaryTermination = { true }

        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateCancel)
        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateNow)
        #expect(prompts == 2)
    }

    @Test func cancelledDiaryCheckRequiresANewQuitConfirmation() {
        let delegate = AppDelegate()
        var prompts = 0
        delegate.presentQuitConfirmation = { _ in prompts += 1; return .alertFirstButtonReturn }
        delegate.confirmDiaryTermination = { false }
        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateCancel)

        delegate.confirmDiaryTermination = { true }
        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateNow)
        #expect(prompts == 2)
    }

    @Test(arguments: [true, false])
    func repeatedQuitIsBlockedDuringEitherConfirmation(_ repeatDuringQuit: Bool) {
        let delegate = AppDelegate()
        var prompts = 0
        var diaryChecks = 0
        delegate.presentQuitConfirmation = { [unowned delegate] _ in
            prompts += 1
            if repeatDuringQuit {
                #expect(delegate.applicationShouldTerminate(NSApp) == .terminateCancel)
            }
            return .alertFirstButtonReturn
        }
        delegate.confirmDiaryTermination = { [unowned delegate] in
            diaryChecks += 1
            if !repeatDuringQuit {
                #expect(delegate.applicationShouldTerminate(NSApp) == .terminateCancel)
            }
            return true
        }

        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateNow)
        #expect(prompts == 1 && diaryChecks == 1)
    }

    @Test func closingTheLastWindowDoesNotQuitTheMenuBarApp() {
        #expect(!AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApp))
    }

    @Test(arguments: ["en", "zh-Hans"])
    func alertUsesLocalizedNativeButtonsAndKeyboardShortcuts(_ language: String) {
        let alert = AppDelegate.quitAlert(locale: Locale(identifier: language))
        let isChinese = language == "zh-Hans"
        #expect(alert.messageText == (isChinese ? "确定要退出 AreaChain？" : "Quit AreaChain?"))
        #expect(alert.informativeText == (isChinese
            ? "退出后菜单栏入口和全局快捷键将不可用。未保存的输入可能丢失。"
            : "The menu bar item and global shortcuts will be unavailable after quitting. Unsaved input may be lost."))
        #expect(alert.buttons.map(\.title) == (isChinese ? ["退出", "取消"] : ["Quit", "Cancel"]))
        #expect(alert.buttons.map(\.keyEquivalent) == ["\r", "\u{1b}"])
        #expect(alert.alertStyle == .warning)
        #expect(!alert.showsSuppressionButton)
    }

    @Test(arguments: QuitInteraction.allCases)
    func nativeModalInteractionReturnsTheExpectedTerminationReply(_ interaction: QuitInteraction) {
        let delegate = AppDelegate()
        let present = delegate.presentQuitConfirmation
        var presentedAlert: NSAlert?
        var diaryChecks = 0
        delegate.presentQuitConfirmation = { alert in
            presentedAlert = alert
            return interactWithModal(alert, interaction: interaction, present: present)
        }
        delegate.confirmDiaryTermination = { diaryChecks += 1; return true }

        let expected: NSApplication.TerminateReply = interaction.confirmsQuit ? .terminateNow : .terminateCancel
        #expect(delegate.applicationShouldTerminate(NSApp) == expected)
        #expect(diaryChecks == (interaction.confirmsQuit ? 1 : 0))
        #expect(presentedAlert?.window.isVisible == false)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func nativeAlertFitsBothLanguagesAndAppearances(_ language: String, _ dark: Bool) {
        let alert = AppDelegate.quitAlert(locale: Locale(identifier: language))
        alert.window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let response = interactWithModal(alert, interaction: .cancel, present: AppDelegate().presentQuitConfirmation) {
            do { try snapshot($0, language: language, dark: dark) }
            catch { Issue.record(error) }
        }
        #expect(response == .alertSecondButtonReturn)
    }

    enum QuitInteraction: CaseIterable {
        case cancel, quit, escape

        var confirmsQuit: Bool { self == .quit }

        @MainActor func perform(on alert: NSAlert) {
            switch self {
            case .cancel: alert.buttons[1].performClick(nil)
            case .quit: alert.buttons[0].performClick(nil)
            case .escape:
                let event = NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: alert.window.windowNumber, context: nil,
                    characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                    isARepeat: false, keyCode: 53
                )!
                alert.window.sendEvent(event)
            }
        }
    }

    private func interactWithModal(
        _ alert: NSAlert, interaction: QuitInteraction,
        present: (NSAlert) -> NSApplication.ModalResponse,
        beforeInteraction: @escaping (NSAlert) -> Void = { _ in }
    ) -> NSApplication.ModalResponse {
        var interacted = false
        let action = Timer(timeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard alert.window.isVisible, !interacted else { return }
                interacted = true
                // XCTest 禁止应用激活；在宿主内校验回车的默认按钮绑定，不伪造键盘焦点。
                #expect(alert.window.defaultButtonCell === alert.buttons[0].cell)
                beforeInteraction(alert)
                interaction.perform(on: alert)
            }
        }
        let timeout = Timer(timeInterval: 3, repeats: false) { _ in
            MainActor.assumeIsolated {
                Issue.record("原生退出确认未响应，已停止测试模态循环")
                NSApp.abortModal()
            }
        }
        RunLoop.main.add(action, forMode: .modalPanel)
        RunLoop.main.add(timeout, forMode: .modalPanel)
        defer { action.invalidate(); timeout.invalidate() }
        let response = present(alert)
        #expect(interacted)
        return response
    }

    private func snapshot(_ alert: NSAlert, language: String, dark: Bool) throws {
        let view = try #require(alert.window.contentView)
        view.layoutSubtreeIfNeeded()
        for button in alert.buttons {
            #expect(view.bounds.contains(view.convert(button.bounds, from: button)))
        }
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "quit-confirmation-\(language)-\(dark ? "dark" : "light").png"
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
