import AppKit
import SwiftUI

extension Color {
    /// 必须具名：`NSColor(name: nil)` 的动态色在 SwiftUI Button 拷贝时会 SIGSEGV。
    static func daybook(name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name), dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }

    static func daybook(
        name: String,
        swatch: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        .daybook(name: name, light: NSColor.daybook(swatch), dark: NSColor.daybook(dark))
    }
}

enum ContrastMath {
    static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func ratio(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let first = relativeLuminance(r: a.0, g: a.1, b: a.2)
        let second = relativeLuminance(r: b.0, g: b.1, b: b.2)
        let high = max(first, second)
        let low = min(first, second)
        return (high + 0.05) / (low + 0.05)
    }
}

extension NSColor {
    static func daybook(_ rgb: (Double, Double, Double)) -> NSColor {
        NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }

    static func daybook(name: String, light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: NSColor.Name(name), dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    static func daybook(
        name: String,
        swatch: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> NSColor {
        daybook(name: name, light: .daybook(swatch), dark: .daybook(dark))
    }
}

extension View {
    func daybookScroll(featherEdges: Bool = false) -> some View {
        self
            .scrollIndicators(.hidden)
            .background(DaybookScrollerConfigurator())
            .modifier(DaybookScrollEdgeFeatherModifier(enabled: featherEdges))
    }

    @ViewBuilder
    func daybookHideInputChrome() -> some View {
        if #available(macOS 15.4, *) {
            self
                .writingToolsBehavior(.disabled)
                .writingToolsAffordanceVisibility(.hidden)
        } else if #available(macOS 15.0, *) {
            self.writingToolsBehavior(.disabled)
        } else {
            self
        }
    }
}
