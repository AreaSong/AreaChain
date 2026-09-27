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

    /// 测试宿主受沙盒限制，不能写 /tmp 或仓库 build/。
    static var combinedURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("areachain-phase1-baseline.jsonl")
    }

    static func prepare() throws {
        guard !prepared else { return }
        prepared = true
        try Data().write(to: combinedURL)
    }

    static func write(_ sample: Phase1Sample) throws {
        try prepare()
        let encoder = JSONEncoder()
        let data = try encoder.encode(sample)
        guard var line = String(data: data, encoding: .utf8) else {
            throw Phase1ContractError.message("基线 JSON 编码失败")
        }
        line.append("\n")
        try append(line, to: combinedURL)
        try append(line, to: scaleURL(sample.scale))
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
        FileManager.default.temporaryDirectory.appendingPathComponent("areachain-phase1-\(scale).jsonl")
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

    static func record(
        scenario: String,
        corpus: Phase1Corpus,
        fetchCalls: Int,
        resultRows: Int,
        repeatScans: Int = 1,
        extraCalls: [String: Int] = [:],
        notes: String,
        approximate: Bool = true,
        warmup: Int = 1,
        samples: Int = 7,
        work: () throws -> Int
    ) throws {
        var times: [Double] = []
        var lastRows = resultRows
        for _ in 0..<warmup {
            lastRows = try work()
        }
        let rssBefore = Phase1Clock.rss()
        for _ in 0..<samples {
            let timed = try Phase1Clock.millis { try work() }
            lastRows = timed.0
            times.append(timed.1)
        }
        let rssAfter = Phase1Clock.rss()
        let sorted = times.sorted()
        let mean = times.reduce(0, +) / Double(times.count)
        let info = ProcessInfo.processInfo
        let sample = Phase1Sample(
            scenario: scenario,
            scale: corpus.graph.scale,
            store: corpus.graph.store,
            temperature: "hot_after_\(warmup)_warmup",
            sampleCount: samples,
            warmup: warmup,
            p50Ms: Phase1Clock.roundMs(Phase1Clock.percentile(sorted, 0.50)),
            p95Ms: Phase1Clock.roundMs(Phase1Clock.percentile(sorted, 0.95)),
            minMs: Phase1Clock.roundMs(sorted.first ?? 0),
            maxMs: Phase1Clock.roundMs(sorted.last ?? 0),
            meanMs: Phase1Clock.roundMs(mean),
            mainActor: true,
            fetchCalls: fetchCalls,
            resultRows: lastRows,
            repeatScans: repeatScans,
            extraCalls: extraCalls,
            rssBefore: rssBefore,
            rssAfter: rssAfter,
            notes: notes,
            os: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory,
            buildConfiguration: "Debug",
            approximate: approximate
        )
        try Phase1Log.write(sample)
    }

    static func coldThenHot(
        scenario: String,
        corpus: Phase1Corpus,
        notes: String,
        cold: () throws -> (fetchCalls: Int, rows: Int),
        hot: () throws -> Int
    ) throws {
        let coldTimed = try Phase1Clock.millis { try cold() }
        let info = ProcessInfo.processInfo
        let coldSample = Phase1Sample(
            scenario: scenario + ".cold",
            scale: corpus.graph.scale,
            store: corpus.graph.store,
            temperature: "cold_new_context",
            sampleCount: 1,
            warmup: 0,
            p50Ms: Phase1Clock.roundMs(coldTimed.1),
            p95Ms: Phase1Clock.roundMs(coldTimed.1),
            minMs: Phase1Clock.roundMs(coldTimed.1),
            maxMs: Phase1Clock.roundMs(coldTimed.1),
            meanMs: Phase1Clock.roundMs(coldTimed.1),
            mainActor: true,
            fetchCalls: coldTimed.0.fetchCalls,
            resultRows: coldTimed.0.rows,
            repeatScans: 1,
            extraCalls: [:],
            rssBefore: 0,
            rssAfter: Phase1Clock.rss(),
            notes: notes + "；冷路径只有 1 次，p50/p95 等于该次。",
            os: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory,
            buildConfiguration: "Debug",
            approximate: true
        )
        try Phase1Log.write(coldSample)
        try record(
            scenario: scenario + ".hot",
            corpus: corpus,
            fetchCalls: coldTimed.0.fetchCalls,
            resultRows: coldTimed.0.rows,
            notes: notes,
            work: hot
        )
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
        let info = ProcessInfo.processInfo
        try Phase1Log.write(
            Phase1Sample(
                scenario: scenario,
                scale: corpus.graph.scale,
                store: corpus.graph.store,
                temperature: temperature,
                sampleCount: 1,
                warmup: 0,
                p50Ms: ms,
                p95Ms: ms,
                minMs: ms,
                maxMs: ms,
                meanMs: ms,
                mainActor: true,
                fetchCalls: fetchCalls,
                resultRows: resultRows,
                repeatScans: 1,
                extraCalls: extraCalls,
                rssBefore: 0,
                rssAfter: Phase1Clock.rss(),
                notes: notes,
                os: info.operatingSystemVersionString,
                processorCount: info.processorCount,
                physicalMemoryBytes: info.physicalMemory,
                buildConfiguration: "Debug",
                approximate: true
            )
        )
    }
}
