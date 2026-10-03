import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchLayoutTests {
    @Test func nativeLayoutMatrixAndScrolling() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for locale in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 760 : 380)
                        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark, text: "/")
                        defer { host.close() }
                        try await host.start()
                        let field = try host.field
                        let initial = field.convert(field.bounds, to: nil)
                        let state = try host.state
                        #expect(state.suggestions.candidates.count > 20)
                        for _ in 0..<12 { try await host.key(125, "\u{f701}") }
                        #expect(state.suggestions.selectedIndex == 12)
                        #expect(field.convert(field.bounds, to: nil) == initial)
                        let panel = try NativeSyntaxUI.frame("syntax.unified.candidates", in: host.window)
                        #expect(panel.maxY <= host.window.contentView!.bounds.maxY)
                        #expect(panel.minY > initial.maxY)
                        let selected = try #require(state.suggestions.selectedCandidate())
                        let selectedFrame = try NativeSyntaxUI.frame("syntax.candidate." + selected.id, in: host.window)
                        #expect(selectedFrame.intersects(panel))
                        try host.snapshot("\(layout)-\(locale)-\(dark)-\(minimum)")
                        try await host.key(53, "\u{1b}")
                        #expect(host.model.buffer.text == "/")
                        #expect(field.convert(field.bounds, to: nil) == initial)
                    }
                }
            }
        }
    }

    @Test func fallbackBelowAndMouseAcceptance() async throws {
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, top: true, text: "/set")
        defer { host.close() }
        try await host.start()
        let state = try host.state
        let source = try #require(state.completion)
        let first = try #require(source.result.candidates.first)
        let field = try host.field
        let initial = field.convert(field.bounds, to: nil)
        let panel = try NativeSyntaxUI.frame("syntax.unified.candidates", in: host.window)
        #expect(panel.maxY < initial.minY)
        try host.snapshot("compact-below")
        let point = try NativeSyntaxUI.center("syntax.candidate." + first.id, in: host.window)
        try await host.click(point)
        #expect(host.window.firstResponder === (try host.editor))
        #expect(host.model.edits.filter { $0.acceptance != nil }.count == 1)
        #expect(field.convert(field.bounds, to: nil) == initial)
    }

    @Test func aliasesDiagnosticsAndUnavailableParameters() async throws {
        let host = UnifiedSearchTestHost(locale: "zh-Hans")
        defer { host.close() }
        try await host.start()
        for text in ["普通文字", "/", "/set", "/setting", "/setting/", "/settings", "/设置", "/语言", "/setting/language/chinese", "/setting/unknown"] {
            host.model.replace(text)
            try await host.settle()
            let state = try host.state
            let result = try #require(state.completion?.result)
            #expect(result.input == text)
            if text == "/setting/unknown" { #expect(result.state == .invalid) }
            if text == "/setting/language/chinese" {
                #expect(result.arguments.count == 1)
                #expect(result.command?.isExecutable == false)
            }
            if text == "普通文字" { #expect(result.state == .ordinaryText && result.candidates.isEmpty) }
        }
    }
    @Test func longDescriptionsNoCandidatesAndOutsideClick() async throws {
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: true,
                                         text: "/", reduceMotion: true)
        defer { host.close() }
        try await host.start()
        let state = try host.state
        let source = try #require(state.completion)
        let longest = try #require(source.result.candidates.max { $0.summary.count < $1.summary.count })
        state.suggestions.selectedIndex = try #require(source.result.candidates.firstIndex(of: longest))
        try await host.settle()
        try host.snapshot("compact-long-description-reduced-motion")
        try await host.click(NSPoint(x: 20, y: 20))
        #expect(!state.suggestions.isActive && host.model.buffer.text == "/")
        host.model.replace("/setting/unknown")
        try await host.settle()
        #expect(state.completion?.result.state == .invalid)
        #expect(state.suggestions.candidates.isEmpty)
        try host.snapshot("compact-unknown-no-candidates")
    }

}
