import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookSecureFieldTests {
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test func consumerSubmitModifiersForwardWithoutSecurityActions() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SecureFieldState()
        let submit = { state.submits += 1 }
        // B 的函数引用和 C 的闭包修饰形式只回调计数，不创建配置或调用认证。
        let content = VStack {
            DaybookSecureField("privacy.master.label", text: state.binding).onSubmit(submit)
            DaybookSecureField("privacy.master.placeholder", text: Binding(
                get: { state.second }, set: { state.second = $0 })).onSubmit { submit() }
        }.padding(24)
        let window = fixture.window(content, size: NSSize(width: 300, height: 140))
        defer { FormInputTestSupport.release(window) }
        try await Secure.ready(window)
        for index in 0..<2 {
            try await Secure.enter(Secure.sample, index: index, in: window)
            let before = state.submits
            try await FormInputTestSupport.key(36, text: "\r", flags: .command, in: window)
            #expect(state.submits == before)
            try await FormInputTestSupport.key(36, text: "\r", in: window)
            #expect(state.submits == before + 1)
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func localizedVerbatimExternalUpdatesAndDisabled(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SecureFieldState()
        state.locale = locale
        let host = fixture.window(SecureFieldContent(state: state), scheme: scheme, size: NSSize(width: 300, height: 180))
        defer { FormInputTestSupport.release(host) }
        try await Secure.ready(host)
        let fields = Secure.fields(host)
        #expect(fields.count == 3 && state.writes == 0 && state.submits == 0)
        let first = try #require(fields.first)
        #expect(first.placeholderString == L10n.string("privacy.master.label", locale: Locale(identifier: locale)))
        #expect(fields[1].placeholderString == "common.save" && !fields[2].isEnabled)
        let nodes = Native.elements(host.contentView).filter {
            Native.value($0, "accessibilitySubrole") as? String == "AXSecureTextField"
        }
        #expect(nodes.count == 3)
        #expect(nodes.contains { Native.value($0, "accessibilityLabel") as? String == first.placeholderString })
        #expect(nodes.contains { Native.value($0, "accessibilityLabel") as? String == "common.save" })
        #expect(fields.allSatisfy { ($0.cell as? NSSecureTextFieldCell)?.echosBullets == true })
        try await Secure.enter(Secure.sample, in: host)
        let accepted = state.first.utf8.elementsEqual(Secure.sample.utf8)
        #expect(accepted && state.second.isEmpty)
        try Native.snapshot(host, name: "secure-component-focused-\(locale)-\(scheme)")
        let writes = state.writes
        state.first = ""
        state.second = Secure.sample
        state.locale = locale == "en" ? "zh-Hans" : "en"
        try await SystemPageHost.settle(host)
        let external = fields[1].stringValue.utf8.elementsEqual(Secure.sample.utf8)
        #expect(first.stringValue.isEmpty && external)
        print("Secure external writes before=\(writes) after=\(state.writes) emptyProposal=\(state.lastProposalWasEmpty)")
        #expect(state.lastProposalWasEmpty && state.submits == 0)
        #expect(first.placeholderString == L10n.string("privacy.master.label", locale: Locale(identifier: state.locale)))
        host.makeFirstResponder(nil)
        try await SystemPageHost.settle(host)
        try Native.assertBounds(fields, in: host)
        try Native.snapshot(host, name: "secure-component-blurred-\(locale)-\(scheme)")
        #expect(state.submits == 0)
    }

    @Test(arguments: [false, true])
    func externalUpdateEchoComparedWithNative(native: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SecureFieldState()
        let host = fixture.window(SecureFieldNativeComparison(state: state, native: native),
                                  size: NSSize(width: 300, height: 100))
        defer { FormInputTestSupport.release(host) }
        try await Secure.ready(host)
        try await Secure.enter(Secure.sample, in: host)
        let writes = state.writes
        state.first = ""
        try await SystemPageHost.settle(host)
        #expect(Secure.fields(host).allSatisfy { $0.stringValue.isEmpty })
        #expect(state.writes == writes && state.submits == 0)
        state.locale = "zh-Hans"
        try await SystemPageHost.settle(host)
        print("Secure locale native=\(native) before=\(writes) after=\(state.writes) emptyProposal=\(state.lastProposalWasEmpty)")
        #expect(Secure.fields(host).allSatisfy { $0.stringValue.isEmpty } && state.submits == 0)
    }

    @Test func rejectingBindingRefreshRebuildAndUnmountDoNotSubmit() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SecureFieldState()
        state.reject = true
        let host = fixture.window(SecureFieldContent(state: state), size: NSSize(width: 300, height: 180))
        defer { FormInputTestSupport.release(host) }
        try await Secure.ready(host)
        let field = try #require(Secure.fields(host).first)
        let editor = try await FormInputTestSupport.editor(field, in: host)
        editor.insertText(Secure.sample, replacementRange: NSRange(location: 0, length: 0))
        try await SystemPageHost.settle(host)
        #expect(state.first.isEmpty && state.writes > 0)
        host.makeFirstResponder(nil)
        state.first = ""
        state.generation += 1
        try await SystemPageHost.settle(host)
        #expect(Secure.fields(host).allSatisfy { $0.stringValue.isEmpty })
        state.reject = false
        try await Secure.enter(Secure.sample, in: host)
        state.first = ""
        try await SystemPageHost.settle(host)
        let writes = state.writes
        state.visible = false
        try await SystemPageHost.settle(host)
        state.visible = true
        try await SystemPageHost.settle(host)
        #expect(Secure.fields(host).allSatisfy { $0.stringValue.isEmpty })
        #expect(state.writes == writes && state.submits == 0)
    }
}

/// 这里只是测试宿主的外部 Binding 所有者；公共组件不持有这些字符串。
@MainActor @Observable
private final class SecureFieldState {
    var first = ""
    var second = ""
    var writes = 0
    var submits = 0
    var reject = false
    var lastProposalWasEmpty = true
    var locale = "en"
    var generation = 0
    var visible = true

    var binding: Binding<String> {
        Binding(get: { self.first }, set: {
            self.writes += 1
            self.lastProposalWasEmpty = $0.isEmpty
            if !self.reject { self.first = $0 }
        })
    }
}

private struct SecureFieldContent: View {
    @Bindable var state: SecureFieldState
    var body: some View {
        VStack(spacing: DaybookSpacing.md) {
            if state.visible {
                DaybookSecureField("privacy.master.label", text: state.binding)
                    .id(state.generation).accessibilityIdentifier("secure.primary")
                DaybookSecureField(verbatim: "common.save", text: $state.second)
                    .accessibilityIdentifier("secure.verbatim")
                DaybookSecureField("privacy.password.repeat", text: .constant("")).disabled(true)
                    .accessibilityIdentifier("secure.disabled")
            }
        }
        .padding(DaybookSpacing.lg)
        .background(DaybookPalette.fill.page)
        .onSubmit { state.submits += 1 }
        .environment(\.locale, Locale(identifier: state.locale))
    }
}

private struct SecureFieldNativeComparison: View {
    @Bindable var state: SecureFieldState
    let native: Bool
    var body: some View {
        Group {
            if native { SecureField("privacy.master.label", text: state.binding) }
            else { DaybookSecureField("privacy.master.label", text: state.binding) }
        }
        .padding(DaybookSpacing.lg)
        .onSubmit { state.submits += 1 }
        .environment(\.locale, Locale(identifier: state.locale))
    }
}
