import AppKit
import Testing
@testable import AreaChain

/// 用公开排版钩子计时，原样调用系统 NSATSTypesetter；原字形/折行策略不变。
private final class CommandProfilingTypesetter: NSATSTypesetter {
    override func layoutCharacters(in characterRange: NSRange, for layoutManager: NSLayoutManager,
                                   maximumNumberOfLineFragments maxNumLines: Int) -> NSRange {
        CommandTextTiming.measure("layout") {
            super.layoutCharacters(in: characterRange, for: layoutManager, maximumNumberOfLineFragments: maxNumLines)
        }
    }
}

@MainActor final class CommandTextPerformancePhases {
    private var totals: [String: Double] = [:]
    private(set) var rows: [[String: Any]] = []

    func install(in editor: CommandProtectedTextView) {
        let original = editor.layoutManager!.typesetter
        let probe = CommandProfilingTypesetter()
        probe.usesFontLeading = original.usesFontLeading
        probe.typesetterBehavior = original.typesetterBehavior
        probe.hyphenationFactor = original.hyphenationFactor
        editor.layoutManager?.typesetter = probe
        CommandTextTiming.observe = { [weak self] phase, value in
            MainActor.assumeIsolated { self?.totals[phase, default: 0] += value }
        }
    }

    func begin() { totals.removeAll() }

    func record(mode: String, bytes: Int, sample: Int, operation: String, total: Double, metadata: [String: Any] = [:]) {
        var row: [String: Any] = ["mode": mode, "bytes": bytes, "sample": sample, "operation": operation,
                     "totalMS": total, "phasesMS": totals, "width": 400, "paragraphs": 1,
                     "position": "end", "visible": false, "prelayout": false,
                     "phaseTimesAreNested": true]
        row.merge(metadata) { _, new in new }
        rows.append(row)
    }

    func export() throws {
        let payload: [String: Any] = ["rows": rows, "os": ProcessInfo.processInfo.operatingSystemVersionString,
                                     "configuration": "Debug", "coldProcess": false]
        Attachment.record(try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), named: "CM1R-phases.json")
    }
}
