import Darwin
import Foundation

/// 阶段 1 只记录测量，不设产品预算。分位数在小样本上是近似值。
struct Phase1Sample: Codable {
    var scenario: String
    var scale: Int
    var store: String
    var temperature: String
    var sampleCount: Int
    var warmup: Int
    var p50Ms: Double
    var p95Ms: Double
    var minMs: Double
    var maxMs: Double
    var meanMs: Double
    var mainActor: Bool
    var fetchCalls: Int
    var resultRows: Int
    var repeatScans: Int
    var extraCalls: [String: Int]
    var rssBefore: UInt64
    var rssAfter: UInt64
    var notes: String
    var os: String
    var processorCount: Int
    var physicalMemoryBytes: UInt64
    var buildConfiguration: String
    var approximate: Bool
    /// 目前只能量 wall；全部在 MainActor 上，不能拆 IO / 后台 / 纯算法。
    var clock: String
}

struct Phase1Work {
    var rows: Int
    var fetchCalls: Int
}

enum Phase1ContractError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

enum Phase1Clock {
    static func millis<T>(_ work: () throws -> T) rethrows -> (T, Double) {
        let start = ProcessInfo.processInfo.systemUptime
        let value = try work()
        return (value, (ProcessInfo.processInfo.systemUptime - start) * 1_000)
    }

    static func millis(_ work: () throws -> Void) rethrows -> Double {
        try millis { try work(); return () }.1
    }

    static func rss() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "task_info failed: \(result)")
        return info.resident_size
    }

    static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int(ceil(fraction * Double(sorted.count))) - 1))
        return sorted[index]
    }

    static func roundMs(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }
}

enum Phase1Log {
    private static var prepared = false
    /// 每次测试进程单独目录，避免追加到日用容器里上次留下的 scale 文件。
    private static let runDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "areachain-phase1-run-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)",
            isDirectory: true
        )

    /// 测试宿主受沙盒限制，不能写 /tmp 或仓库 build/。
    static var combinedURL: URL {
        runDirectory.appendingPathComponent("baseline.jsonl")
    }

    static func prepare() throws {
        guard !prepared else { return }
        prepared = true
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try Data().write(to: combinedURL)
    }

    static func write(_ sample: Phase1Sample) throws {
        try prepare()
        try append(encodedLine(sample), to: combinedURL)
        try append(encodedLine(sample), to: scaleURL(sample.scale))
    }

    static func writeGraph(_ graph: Phase1Graph) throws {
        try prepare()
        let encoder = JSONEncoder()
        let data = try encoder.encode(graph)
        guard var line = String(data: data, encoding: .utf8) else {
            throw Phase1ContractError.message("图规模 JSON 编码失败")
        }
        line = "GRAPH \(line)\n"
        try append(line, to: combinedURL)
        try append(line, to: scaleURL(graph.scale))
    }

    static func scaleURL(_ scale: Int) -> URL {
        runDirectory.appendingPathComponent("scale-\(scale).jsonl")
    }

    private static func encodedLine(_ sample: Phase1Sample) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(sample)
        guard var line = String(data: data, encoding: .utf8) else {
            throw Phase1ContractError.message("基线 JSON 编码失败")
        }
        line.append("\n")
        return line
    }

    private static func append(_ line: String, to url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        guard let data = line.data(using: .utf8) else {
            throw Phase1ContractError.message("基线日志编码失败")
        }
        try handle.write(contentsOf: data)
    }
}

@MainActor
enum Phase1Measure {
    static let warmup = 1
    static let samples = 7
    static let clockKind = "wall_ms_mainActor"

    static func record(
        scenario: String,
        corpus: Phase1Corpus,
        repeatScans: Int = 1,
        extraCalls: [String: Int] = [:],
        notes: String,
        approximate: Bool = true,
        warmup: Int = 1,
        samples: Int = 7,
        work: () throws -> Phase1Work
    ) throws {
        var times: [Double] = []
        var last = Phase1Work(rows: 0, fetchCalls: 0)
        for _ in 0..<warmup {
            last = try work()
        }
        let rssBefore = Phase1Clock.rss()
        for _ in 0..<samples {
            let timed = try Phase1Clock.millis { try work() }
            last = timed.0
            times.append(timed.1)
        }
        let rssAfter = Phase1Clock.rss()
        let sorted = times.sorted()
        let mean = times.reduce(0, +) / Double(times.count)
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario,
                    temperature: "hot_after_\(warmup)_warmup",
                    sampleCount: samples,
                    warmup: warmup,
                    times: sorted,
                    mean: mean,
                    fetchCalls: last.fetchCalls,
                    resultRows: last.rows,
                    repeatScans: repeatScans,
                    extraCalls: extraCalls,
                    rssBefore: rssBefore,
                    rssAfter: rssAfter,
                    notes: notes,
                    approximate: approximate
                )
            )
        )
    }

    static func coldThenHot(
        scenario: String,
        corpus: Phase1Corpus,
        notes: String,
        cold: () throws -> Phase1Work,
        hot: () throws -> Phase1Work
    ) throws {
        let coldTimed = try Phase1Clock.millis { try cold() }
        let ms = Phase1Clock.roundMs(coldTimed.1)
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario + ".cold",
                    temperature: "cold_new_context",
                    sampleCount: 1,
                    warmup: 0,
                    times: [ms],
                    mean: ms,
                    fetchCalls: coldTimed.0.fetchCalls,
                    resultRows: coldTimed.0.rows,
                    repeatScans: 1,
                    extraCalls: [:],
                    rssBefore: 0,
                    rssAfter: Phase1Clock.rss(),
                    notes: notes + "；冷路径只有 1 次，p50/p95 等于该次。时钟仅为 wall。",
                    approximate: true
                )
            )
        )
        try record(scenario: scenario + ".hot", corpus: corpus, notes: notes, work: hot)
    }

    static func writeSingle(
        scenario: String,
        corpus: Phase1Corpus,
        elapsedMs: Double,
        fetchCalls: Int,
        resultRows: Int,
        extraCalls: [String: Int],
        notes: String,
        temperature: String = "single"
    ) throws {
        let ms = Phase1Clock.roundMs(elapsedMs)
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario,
                    temperature: temperature,
                    sampleCount: 1,
                    warmup: 0,
                    times: [ms],
                    mean: ms,
                    fetchCalls: fetchCalls,
                    resultRows: resultRows,
                    repeatScans: 1,
                    extraCalls: extraCalls,
                    rssBefore: 0,
                    rssAfter: Phase1Clock.rss(),
                    notes: notes,
                    approximate: true
                )
            )
        )
    }

    private struct SampleDraft {
        var scenario: String
        var temperature: String
        var sampleCount: Int
        var warmup: Int
        var times: [Double]
        var mean: Double
        var fetchCalls: Int
        var resultRows: Int
        var repeatScans: Int
        var extraCalls: [String: Int]
        var rssBefore: UInt64
        var rssAfter: UInt64
        var notes: String
        var approximate: Bool
    }

    private static func sample(corpus: Phase1Corpus, draft: SampleDraft) -> Phase1Sample {
        let info = ProcessInfo.processInfo
        let sorted = draft.times.sorted()
        return Phase1Sample(
            scenario: draft.scenario,
            scale: corpus.graph.scale,
            store: corpus.graph.store,
            temperature: draft.temperature,
            sampleCount: draft.sampleCount,
            warmup: draft.warmup,
            p50Ms: Phase1Clock.roundMs(Phase1Clock.percentile(sorted, 0.50)),
            p95Ms: Phase1Clock.roundMs(Phase1Clock.percentile(sorted, 0.95)),
            minMs: Phase1Clock.roundMs(sorted.first ?? 0),
            maxMs: Phase1Clock.roundMs(sorted.last ?? 0),
            meanMs: Phase1Clock.roundMs(draft.mean),
            mainActor: true,
            fetchCalls: draft.fetchCalls,
            resultRows: draft.resultRows,
            repeatScans: draft.repeatScans,
            extraCalls: draft.extraCalls,
            rssBefore: draft.rssBefore,
            rssAfter: draft.rssAfter,
            notes: draft.notes,
            os: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory,
            buildConfiguration: "Debug",
            approximate: draft.approximate,
            clock: clockKind
        )
    }
}
