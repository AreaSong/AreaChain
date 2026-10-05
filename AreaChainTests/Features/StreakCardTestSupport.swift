import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Observable @MainActor
final class StreakCardProbe {
    var config = StreakCardConfig(streakResult: StreakResult(currentStreak: 7, bestStreak: 21),
        isEnabled: true, inspectDayKey: "2026-09-09", flags: StreakInspectionFlags())
}

/// 只装配生产卡片；28pt 对应检查器 16pt 和分区 12pt 边距。
struct StreakCardSample: View {
    var probe: StreakCardProbe

    var body: some View {
        TaskDetailStreakCard(config: probe.config)
            .background(SyntaxViewAnchor("syntax.streak.card"))
            .padding(28)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(DaybookPalette.fill.page)
    }
}

@MainActor
enum StreakCardTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func text(_ node: NSObject) -> String {
        for key in ["accessibilityValue", "accessibilityLabel", "accessibilityTitle"] {
            if let value = Native.value(node, key) as? String, !value.isEmpty { return value }
        }
        return ""
    }

    static func texts(_ window: NSWindow) -> [NSObject] {
        Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityRole") as? String == "AXStaticText"
        }
    }

    static func node(_ string: String, in window: NSWindow) throws -> NSObject {
        let matches = texts(window).filter { text($0) == string }
        return try #require(matches.first, "未呈现完整文字：\(string)，实际 \(texts(window).map(text))")
    }

    static func localized(_ key: String, locale: String) -> String {
        L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
    }

    static func assertMetrics(_ result: StreakResult, locale: String, in window: NSWindow) throws {
        let current = try Native.frame(node(localized("drawer.streak.current", locale: locale), in: window), in: window)
        let best = try Native.frame(node(localized("drawer.streak.best", locale: locale), in: window), in: window)
        // 基线确认 Text 的整数插值带本地化分组；这里只生成断言，生产仍保持原插值。
        let format = IntegerFormatStyle<Int>.number.locale(Locale(identifier: locale))
        let currentValue = try Native.frame(node(result.currentStreak.formatted(format), in: window), in: window)
        let bestValue = try Native.frame(node(result.bestStreak.formatted(format), in: window), in: window)
        #expect(current.minX < best.minX)
        // 旧布局的长数字会多行换行；两列高度不同时，外层 HStack 按中心对齐。
        if result.currentStreak < 1000 && result.bestStreak < 1000 {
            #expect(abs(current.minY - best.minY) < 0.01)
        }
        #expect(currentValue.minX < bestValue.minX)
        #expect(currentValue.minX >= current.minX && currentValue.maxX < best.minX)
        #expect(bestValue.minX >= best.minX)
        let units = texts(window).filter { text($0) == localized("drawer.streak.days", locale: locale) }
        #expect(units.count == 2)
        let images = Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityRole") as? String == "AXImage"
        }
        let trophy = try #require(images.first { text($0) == "trophy.fill" })
        // 系统会本地化火焰辅助名称；按指标行几何定位，图形由完整卡片像素基线核对。
        let flame = try #require(images.first {
            let frame = try Native.frame($0, in: window)
            return frame.maxX < currentValue.minX && abs(frame.midY - currentValue.midY) < 2
        })
        #expect(try Native.frame(flame, in: window).maxX < currentValue.minX)
        #expect(try Native.frame(trophy, in: window).maxX < bestValue.minX)
        _ = try node(localized("drawer.streak.title", locale: locale), in: window)
    }

    static func record(_ window: NSWindow, name: String) throws {
        let phase = ProcessInfo.processInfo.environment["AREACHAIN_STREAK_PHASE"] ?? "current"
        let prefix = "9d-\(phase)-\(name)"
        try OverlaySurfaceTestSupport.record(window, name: prefix)
        let entries = try Native.elements(window.contentView).compactMap { node -> [String: String]? in
            guard let role = Native.value(node, "accessibilityRole") as? String,
                  ["AXStaticText", "AXImage", "AXSplitter"].contains(role) else { return nil }
            return ["role": role, "text": text(node), "frame": NSStringFromRect(try Native.frame(node, in: window))]
        }.sorted { left, right in
            ["role", "text", "frame"].map { left[$0] ?? "" }.joined()
                < ["role", "text", "frame"].map { right[$0] ?? "" }.joined()
        }
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        try JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appending(path: prefix + "-text.json"))
        print("STREAK_CARD \(prefix) evidence=\(directory.path)")
    }
}
