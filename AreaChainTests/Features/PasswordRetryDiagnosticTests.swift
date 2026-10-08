import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 每个参数只执行固定一次；重复预算由 case 列表声明，禁止直到成功式重试。
@Suite(.serialized) @MainActor
struct PasswordRetryDiagnosticTests {
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test func replacementRangesRespectExistingSampleCharacters() {
        let text = Secure.sample
        let ranges = Secure.characterRanges(text)
        let legal = zip(ranges, text).allSatisfy { range, character in
            (text as NSString).substring(with: range).utf8.elementsEqual(String(character).utf8)
        }
        let contiguous = zip(ranges, ranges.dropFirst()).allSatisfy { NSMaxRange($0) == $1.location }
        let complete = ranges.first?.location == 0 && ranges.last.map(NSMaxRange) == text.utf16.count
        #expect(legal && contiguous && complete && ranges.count == text.count)
    }

    @Test(arguments: [false, true])
    func fixedEntryWholeAndInPlace(native: Bool) async throws {
        // 预算在执行前固定：两种原生承载分别运行，不在试验内交替焦点。
        for mode in [Secure.Replacement.whole, .inPlace] {
            for round in 1...3 { try await replacementTrial(native: native, mode: mode, round: round) }
        }
    }

    @Test(arguments: [false, true])
    func fixedEntryGrowingIntermediate(native: Bool) async throws {
        // 独立定向选择，只有 A/B 不能区分时才运行；不因结果追加轮数。
        for round in 1...3 { try await replacementTrial(native: native, mode: .growing, round: round) }
    }

    private func replacementTrial(native: Bool, mode: Secure.Replacement, round: Int) async throws {
        let fixture = try Native(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let probe = PasswordBindingProbe(native: native)
        let host = fixture.window(PasswordBindingContent(probe: probe, singleField: true),
                                  size: NSSize(width: 440, height: 160))
        defer { FormInputTestSupport.release(host) }
        try await Secure.ready(host)
        let field = try #require(Secure.fields(host).first)
        let editor = try await FormInputTestSupport.editor(field, in: host)
        let observation = PasswordReplacementObservation(window: host, field: field, editor: editor,
            probe: probe, run: "\(mode.rawValue)-n\(native)-r\(round)")
        defer { observation.stop() }
        try await prepareReplacementRetry(observation)
        try observation.replace(mode, phase: 5)
        try await observation.checkpoints("retry-input")
        observation.filled()
        probe.phase = 6
        probe.beginAction()
        try await observation.checkpoints("retry-clear")
        try observation.outcome()
        // 成功只在残留结论之后完成；不做 Return、重开或重新赋空恢复。
        probe.finishAction(failure: false)
    }

    private func prepareReplacementRetry(_ observation: PasswordReplacementObservation) async throws {
        try observation.replace(.whole, phase: 1)
        try await observation.checkpoints("initial-input")
        observation.filled()
        observation.probe.phase = 2
        observation.probe.beginAction()
        try await observation.checkpoints("initial-clear")
        let initiallyEmpty = observation.probe.first.isEmpty && observation.field.stringValue.isEmpty
            && observation.editor.string.isEmpty
        try #require(initiallyEmpty)
        try observation.replace(.whole, phase: 3)
        try await observation.checkpoints("busy-input")
        observation.filled()
        observation.probe.phase = 4
        observation.probe.finishAction(failure: true)
        try await observation.checkpoints("failure")
        observation.filled()
    }

    struct Scenario: Sendable, CustomTestStringConvertible {
        let configuration: Int
        let keyboard: Bool
        let busyInput: Int
        let round: Int
        var testDescription: String { "c\(configuration)-k\(keyboard)-b\(busyInput)-r\(round)" }
    }

    nonisolated static let scenarios: [Scenario] = [0, 2].flatMap { configuration in
        [false, true].flatMap { keyboard in
            (1...3).map { Scenario(configuration: configuration, keyboard: keyboard, busyInput: 1, round: $0) }
                + [0, 2].map { Scenario(configuration: configuration, keyboard: keyboard, busyInput: $0, round: 1) }
        }
    } + [1, 3].flatMap { configuration in
        [false, true].map { Scenario(configuration: configuration, keyboard: $0, busyInput: 1, round: 1) }
    }

    @Test(arguments: scenarios)
    func productionSheetBoundedMatrix(scenario: Scenario) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(scenario.configuration)
        let host = fixture.window(probe.host)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        probe.window = sheet
        let trace = PasswordRetryDiagnostics(scenario.testDescription)
        probe.observeAction = { [weak probe, weak sheet] in
            if let probe, let sheet { trace.record("action-entry", in: sheet, probe: probe) }
        }
        trace.record("empty", in: sheet, probe: probe)
        try await trace.fill(sheet, keyboard: scenario.keyboard)
        trace.record("1-initial", in: sheet, probe: probe)
        #expect(trace.enabled("common.save", in: sheet) && trace.enabled("alert.cancel", in: sheet))
        try await trace.submit(in: sheet, probe: probe, phase: "2-submit1")
        #expect(probe.calls == 1 && probe.correctInput && probe.pending != nil)
        if scenario.busyInput != 0 {
            try await trace.fill(sheet, keyboard: scenario.keyboard, text: scenario.busyInput == 1 ? nil : "pending-edit")
        }
        trace.record("3-busy", in: sheet, probe: probe)
        #expect(probe.calls == 1 && !trace.enabled("common.save", in: sheet))
        probe.finish(failure: true)
        try await SystemPageHost.settle(sheet)
        trace.record("4-failure", in: sheet, probe: probe)
        #expect(Secure.hasError(sheet) && probe.correctAfterWait && trace.enabled("alert.cancel", in: sheet))
        try await trace.fill(sheet, keyboard: scenario.keyboard)
        trace.record("5-refill", in: sheet, probe: probe)
        #expect(trace.enabled("common.save", in: sheet))
        try await trace.submit(in: sheet, probe: probe, phase: "6-submit2")
        #expect(probe.calls == 2 && probe.correctInput && !Secure.hasError(sheet))
        let residue = Secure.fields(sheet).contains { !$0.stringValue.isEmpty }
        print("SecureK outcome run=\(scenario.testDescription) residue=\(residue) calls=\(probe.calls) correct=\(probe.correctInput)")
        try Native.snapshot(sheet, name: "K-\(scenario.testDescription)-stable")
        if scenario.busyInput == 1 && !scenario.keyboard && probe.confirmation {
            withKnownIssue("K 诊断保留 B 的同值全量替换清空要求", isIntermittent: true) {
                #expect(!residue)
            }
        } else { #expect(!residue) }
        try await checkRecovery(probe, sheet: sheet, host: host, trace: trace, residue: residue)
    }

    private func checkRecovery(_ probe: PasswordSheetProbe, sheet: NSWindow, host: NSWindow,
                               trace: PasswordRetryDiagnostics, residue: Bool) async throws {
        probe.finish()
        try await SystemPageHost.settle(sheet)
        trace.record("7-success", in: sheet, probe: probe)
        if residue && trace.run.hasSuffix("r3") {
            try await cancelAndReopen(probe, sheet: sheet, host: host, trace: trace)
            #expect(probe.calls == 2 && probe.completed == 1)
            return
        }
        try await FormInputTestSupport.key(36, text: "\r", in: sheet)
        trace.record("7-after-return", in: sheet, probe: probe)
        #expect(probe.calls == 2 && probe.completed == 1)
        if residue && trace.run.hasSuffix("r1") {
            let field = try #require(Secure.fields(sheet).last)
            let editor = try await FormInputTestSupport.editor(field, in: sheet)
            trace.record("8-residue-focused", in: sheet, probe: probe)
            try await FormInputTestSupport.key(0, text: "a", flags: .command, in: sheet)
            trace.record("8-native-select", in: sheet, probe: probe)
            #expect(editor.selectedRange().length == (editor.string as NSString).length)
            try await FormInputTestSupport.key(51, text: "\u{7f}", in: sheet)
            trace.record("8-native-delete", in: sheet, probe: probe)
            #expect(field.stringValue.isEmpty && probe.calls == 2)
        }
        if residue && trace.run.hasSuffix("r2") {
            try await trace.enter(Secure.sample, index: 0, in: sheet, keyboard: true)
            trace.record("8-primary-only", in: sheet, probe: probe)
            #expect(!trace.enabled("common.save", in: sheet))
        }
        // 正常的新输入必须正确提交；清理动作发生于残留取证之后，不用于让清空断言通过。
        try await trace.fill(sheet, keyboard: true, text: Secure.alternateSample)
        try await Secure.click("common.save", in: sheet)
        #expect(probe.calls == 3 && probe.alternateInput && !probe.correctInput)
        trace.record("8-alternate-submitted", in: sheet, probe: probe)
        probe.finish(failure: true)
        try await SystemPageHost.settle(sheet)
        try await cancelAndReopen(probe, sheet: sheet, host: host, trace: trace)
        #expect(probe.calls == 3)
    }

    @Test(arguments: [0, 2])
    func cancelResidualWithoutReturn(configuration: Int) async throws {
        // 只复核原矩阵 r3 的取消分支，防止把 Return 已清掉的字段当作取消清理证据。
        try await productionSheetBoundedMatrix(scenario: Scenario(
            configuration: configuration, keyboard: false, busyInput: 1, round: 3))
    }

    private func cancelAndReopen(_ probe: PasswordSheetProbe, sheet: NSWindow, host: NSWindow,
                                 trace: PasswordRetryDiagnostics) async throws {
        try await Secure.click("alert.cancel", in: sheet)
        try await FormInputTestSupport.wait { host.attachedSheet == nil }
        #expect(probe.dismissals == 1)
        probe.presented = true
        let reopened = try await FormInputTestSupport.sheet(in: host)
        trace.record("9-reopened", in: reopened, probe: probe)
        #expect(Secure.fields(reopened).allSatisfy { $0.stringValue.isEmpty })
    }

    @Test(arguments: [false, true], [false, true])
    func localBindingWriteTiming(native: Bool, keyboard: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordBindingProbe(native: native)
        let host = fixture.window(PasswordBindingContent(probe: probe), size: NSSize(width: 440, height: 160))
        defer { FormInputTestSupport.release(host) }
        try await Secure.ready(host)
        let trace = PasswordRetryDiagnostics("local-n\(native)-k\(keyboard)")
        for phase in 1...3 {
            probe.phase = phase
            try await trace.fill(host, keyboard: keyboard)
            probe.record()
            trace.record("filled-\(phase)", in: host)
            if phase != 2 {
                // 独立宿主外部清空对照，保持原生实例，不参与生产 sheet 结论。
                probe.first = ""
                probe.second = ""
                try await SystemPageHost.settle(host)
                probe.record()
                trace.record("cleared-\(phase)", in: host)
            }
        }
    }
}
