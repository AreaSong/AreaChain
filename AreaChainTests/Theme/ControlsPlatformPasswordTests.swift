import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ControlsPlatformPasswordTests {
    @Test func cancelAndReopenKeepSamplingWithinLiveSheet() async throws {
        let session = ControlsPlatformAcceptance()
        defer { session.close() }
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.selection = .passwordTyping
        session.openSelected()
        let support = try #require(session.password)
        let host = try #require(session.auxiliary)
        let sheet = try await FormInputTestSupport.sheet(in: host)
        support.tick()
        try await SecureInputTestSupport.ready(sheet)
        try await SecureInputTestSupport.enter(ControlsPlatformPassword.sample, in: sheet)
        try await SecureInputTestSupport.click("alert.cancel", locale: "zh-Hans", in: sheet)
        try await SystemPageHost.settle(host)
        support.tick()
        #expect(host.attachedSheet == nil && support.probe.window == nil && support.probe.calls == 0)
        support.probe.presented = true
        let reopened = try await FormInputTestSupport.sheet(in: host)
        support.tick()
        #expect(SecureInputTestSupport.fields(reopened).allSatisfy { $0.stringValue.isEmpty })
        #expect(support.probe.window === reopened && support.probe.dismissals == 1)
    }

    @Test(arguments: [false, true])
    func fakeFailureRetryAndCloseReleasePending(replacement: Bool) async throws {
        let session = ControlsPlatformAcceptance()
        defer { session.close() }
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.selection = replacement ? .passwordReplacement : .passwordTyping
        session.openSelected()
        let support = try #require(session.password)
        let host = try #require(session.auxiliary)
        let sheet = try await FormInputTestSupport.sheet(in: host)
        support.tick()
        try await SecureInputTestSupport.ready(sheet)
        for index in 0..<2 {
            try await SecureInputTestSupport.enter(ControlsPlatformPassword.sample, index: index, in: sheet)
        }
        try await SecureInputTestSupport.click("common.save", locale: "zh-Hans", in: sheet)
        #expect(support.probe.calls == 1 && support.probe.correctInput && support.probe.pending != nil)
        try SecureInputTestSupport.enabled("alert.cancel", false, locale: "zh-Hans", in: sheet)
        for index in 0..<2 {
            try await SecureInputTestSupport.enter(ControlsPlatformPassword.sample, index: index, in: sheet)
        }
        support.tick(now: ProcessInfo.processInfo.systemUptime + 31)
        try await SystemPageHost.settle(sheet)
        #expect(support.probe.pending == nil && support.probe.correctAfterWait)
        #expect(SecureInputTestSupport.hasError(sheet, locale: "zh-Hans"))
        try await SecureInputTestSupport.click("common.save", locale: "zh-Hans", in: sheet)
        #expect(support.probe.calls == 2 && support.probe.correctInput && support.probe.pending != nil)
        session.close()
        try await SystemPageHost.settle(host)
        #expect(support.closed && support.probe.pending == nil && support.probe.completed == 0)
        #expect(host.attachedSheet == nil && sheet.contentView == nil && session.listenersReleased)
        let rows = try ControlsPlatformTestSupport.rows(session)
        #expect(rows.contains { $0["kind"] as? String == "password-sample" })
        let encoded = try JSONSerialization.data(withJSONObject: rows)
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(!text.contains(ControlsPlatformPassword.sample))
        #expect(!text.contains("keyCode") && !text.contains("characters"))
    }
}
