import Foundation

/// 阶段 1 只记录测量，不设产品预算。分位数在小样本上是近似值。
struct Phase1Sample: Codable {
    var scenario = ""
    var scale = 0
    var store = ""
    var temperature = ""
    var sampleCount = 0
    var warmup = 0
    var p50Ms = 0.0
    var p95Ms = 0.0
    var minMs = 0.0
    var maxMs = 0.0
    var meanMs = 0.0
    var p50MainCpuMs = 0.0
    var p50FetchWallMs = 0.0
    var p50ComputeWallMs = 0.0
    var meanInBlock = 0.0
    var meanOutBlock = 0.0
    var mainActor = true
    var fetchCalls = 0
    var resultRows = 0
    var repeatScans = 1
    var extraCalls: [String: Int] = [:]
    var rssBefore: UInt64 = 0
    var rssAfter: UInt64 = 0
    var rssPeakBefore: UInt64 = 0
    var rssPeakAfter: UInt64 = 0
    var rssLoopMax: UInt64 = 0
    var footprintBefore: UInt64 = 0
    var footprintAfter: UInt64 = 0
    var notes = ""
    var os = ""
    var processorCount = 0
    var physicalMemoryBytes: UInt64 = 0
    var buildConfiguration = "Debug"
    var approximate = true
    /// wall=进程单调时钟；main_cpu=当前线程 user+system；fetch/compute=场景内分段；blocks=rusage。
    var clock = ""
    var logDirectory = ""
    var logIsolation = ""
}

struct Phase1Work {
    var rows: Int
    var fetchCalls: Int
    var fetchWallMs: Double = 0
    var computeWallMs: Double = 0

    static func splitting<Payload>(
        fetchCalls: Int,
        fetch: () throws -> Payload,
        compute: (Payload) throws -> Int
    ) throws -> Phase1Work {
        let fetched = try Phase1Clock.millis(fetch)
        let computed = try Phase1Clock.millis { try compute(fetched.0) }
        return Phase1Work(
            rows: computed.0,
            fetchCalls: fetchCalls,
            fetchWallMs: fetched.1.wallMs,
            computeWallMs: computed.1.wallMs
        )
    }
}

enum Phase1ContractError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

enum Phase1Log {
    private struct Storage {
        let directory: URL
        let persistFiles: Bool
    }

    private static var prepared = false
    private static let storage = makeStorage()
    private static let memoryLock = NSLock()
    private static var memoryFiles: [String: String] = [:]

    static var combinedURL: URL {
        storage.directory.appendingPathComponent("baseline.jsonl")
    }

    static var persistsFiles: Bool { storage.persistFiles }

    static var isolationLabel: String {
        if isApplicationContainer(storage.directory) { return "app_container_tmp_fallback" }
        return storage.persistFiles ? "outside_app_container" : "stderr_and_memory"
    }

    static func prepare() throws {
        guard !prepared else { return }
        prepared = true
        if storage.persistFiles {
            try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
            try Data().write(to: combinedURL)
        }
        let location = storage.persistFiles ? combinedURL.path : "-"
        fputs("PHASE1_LOG \(location) isolation=\(isolationLabel)\n", stderr)
    }

    static func write(_ sample: Phase1Sample) throws {
        try prepare()
        try append(encodedLine(sample), to: combinedURL)
        try append(encodedLine(sample), to: scaleURL(sample.scale, store: sample.store))
        // 关键样本同步打到 stderr；沙盒写不进仓库/tmp 时只留内存，不写日用容器。
        if sample.scenario.hasPrefix("backup.") || sample.scenario == "snapshot.exportOrdinaryJSON" {
            fputs("PHASE1_SAMPLE \(try encodedLine(sample))", stderr)
        }
    }

    static func samples() throws -> [Phase1Sample] {
        try prepare()
        let text = try logText(at: combinedURL)
        let decoder = JSONDecoder()
        return try text.split(whereSeparator: \.isNewline).compactMap { line in
            let raw = String(line)
            guard !raw.hasPrefix("GRAPH "), !raw.isEmpty else { return nil }
            return try decoder.decode(Phase1Sample.self, from: Data(raw.utf8))
        }
    }

    static func writeGraph(_ graph: Phase1Graph) throws {
        try prepare()
        var recorded = graph
        recorded.logDirectory = storage.persistFiles ? storage.directory.path : ""
        recorded.logIsolation = isolationLabel
        let encoder = JSONEncoder()
        let data = try encoder.encode(recorded)
        guard var line = String(data: data, encoding: .utf8) else {
            throw Phase1ContractError.message("图规模 JSON 编码失败")
        }
        line = "GRAPH \(line)\n"
        try append(line, to: combinedURL)
        try append(line, to: scaleURL(graph.scale, store: graph.store))
    }

    static func scaleURL(_ scale: Int, store: String) -> URL {
        storage.directory.appendingPathComponent("scale-\(scale)-\(store).jsonl")
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
        if !storage.persistFiles {
            memoryLock.lock()
            memoryFiles[url.lastPathComponent, default: ""] += line
            memoryLock.unlock()
            return
        }
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

    private static func logText(at url: URL) throws -> String {
        if storage.persistFiles {
            return try String(contentsOf: url, encoding: .utf8)
        }
        memoryLock.lock()
        let text = memoryFiles[url.lastPathComponent] ?? ""
        memoryLock.unlock()
        return text
    }

    private static func makeStorage() -> Storage {
        let name = "areachain-phase1-run-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
        if let root = firstWritableRoot() {
            return Storage(directory: root.appendingPathComponent(name, isDirectory: true), persistFiles: true)
        }
        // 非文件路径，不创建、不写入；样本留在进程内存和 stderr。不要打印看起来像真实 /tmp 文件的地址。
        return Storage(
            directory: URL(fileURLWithPath: "/areachain-phase1-not-persisted/\(name)", isDirectory: true),
            persistFiles: false
        )
    }

    /// 只接受沙盒外目录。应用容器（含日用 `com.areachain.app`）一律拒绝。
    private static func firstWritableRoot() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        var candidates: [URL] = []
        for key in ["AREACHAIN_PHASE1_LOG_DIR", "TEST_RUNNER_AREACHAIN_PHASE1_LOG_DIR"] {
            if let override = environment[key], !override.isEmpty {
                candidates.append(URL(fileURLWithPath: override, isDirectory: true))
            }
        }
        candidates.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("build/phase1", isDirectory: true)
        )
        if let sourceRoot = environment["SRCROOT"] {
            candidates.append(URL(fileURLWithPath: sourceRoot).appendingPathComponent("build/phase1", isDirectory: true))
        }
        candidates.append(URL(fileURLWithPath: "/tmp", isDirectory: true))
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        if !isApplicationContainer(cwd) {
            candidates.append(cwd.appendingPathComponent("build/phase1", isDirectory: true))
        }
        return candidates.map { $0.appendingPathComponent("areachain-phase1", isDirectory: true) }
            .first { canWrite(to: $0) }
    }

    private static func isApplicationContainer(_ url: URL) -> Bool {
        url.standardizedFileURL.path.contains("/Library/Containers/")
    }

    private static func canWrite(to directory: URL) -> Bool {
        if isApplicationContainer(directory) { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent("write-probe-\(UUID().uuidString)")
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }
}

@MainActor
enum Phase1Measure {
    static let warmup = 1
    static let samples = 7
    static let clockKind = "wall_ms,main_cpu_ms,fetch_wall_ms,compute_wall_ms,rusage_blocks"

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
        var last = Phase1Work(rows: 0, fetchCalls: 0)
        for _ in 0..<warmup {
            last = try work()
        }
        let series = Phase1Series()
        let before = Phase1Clock.probe()
        var loopMax = before.rss
        for _ in 0..<samples {
            let timed = try Phase1Clock.millis { try work() }
            last = timed.0
            series.append(timing: timed.1, work: last)
            loopMax = max(loopMax, Phase1Clock.probe().rss)
        }
        let after = Phase1Clock.probe()
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario,
                    temperature: "hot_after_\(warmup)_warmup",
                    sampleCount: samples,
                    warmup: warmup,
                    last: last,
                    repeatScans: repeatScans,
                    extraCalls: extraCalls,
                    notes: notes,
                    approximate: approximate,
                    series: series,
                    memory: mark(before: before, after: after, loopMax: loopMax)
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
        let before = Phase1Clock.probe()
        let timed = try Phase1Clock.millis { try cold() }
        let after = Phase1Clock.probe()
        let series = Phase1Series()
        series.append(timing: timed.1, work: timed.0)
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario + ".cold",
                    temperature: "cold_new_context",
                    sampleCount: 1,
                    warmup: 0,
                    last: timed.0,
                    repeatScans: 1,
                    extraCalls: [:],
                    notes: notes + "；冷路径只有 1 次，p50/p95 等于该次。",
                    approximate: true,
                    series: series,
                    memory: mark(before: before, after: after, loopMax: after.rss)
                )
            )
        )
        try record(scenario: scenario + ".hot", corpus: corpus, notes: notes, work: hot)
    }

    static func writeSingle(
        scenario: String,
        corpus: Phase1Corpus,
        timing: Phase1Timing,
        work: Phase1Work,
        extraCalls: [String: Int],
        notes: String,
        temperature: String = "single",
        memory: Phase1MemoryMark? = nil
    ) throws {
        let series = Phase1Series()
        series.append(timing: timing, work: work)
        let probe = Phase1Clock.probe()
        try Phase1Log.write(
            sample(
                corpus: corpus,
                draft: SampleDraft(
                    scenario: scenario,
                    temperature: temperature,
                    sampleCount: 1,
                    warmup: 0,
                    last: work,
                    repeatScans: 1,
                    extraCalls: extraCalls,
                    notes: notes,
                    approximate: true,
                    series: series,
                    memory: memory ?? mark(before: probe, after: probe, loopMax: probe.rss)
                )
            )
        )
    }

    private final class Phase1Series {
        var walls: [Double] = []
        var mainCpus: [Double] = []
        var fetches: [Double] = []
        var computes: [Double] = []
        var inBlocks: [Int64] = []
        var outBlocks: [Int64] = []

        func append(timing: Phase1Timing, work: Phase1Work) {
            walls.append(timing.wallMs)
            mainCpus.append(timing.mainCpuMs)
            fetches.append(work.fetchWallMs)
            computes.append(work.computeWallMs)
            inBlocks.append(timing.inBlock)
            outBlocks.append(timing.outBlock)
        }
    }

    private struct SampleDraft {
        var scenario: String
        var temperature: String
        var sampleCount: Int
        var warmup: Int
        var last: Phase1Work
        var repeatScans: Int
        var extraCalls: [String: Int]
        var notes: String
        var approximate: Bool
        var series: Phase1Series
        var memory: Phase1MemoryMark
    }

    private static func mark(before: Phase1Probe, after: Phase1Probe, loopMax: UInt64) -> Phase1MemoryMark {
        Phase1MemoryMark(
            rssBefore: before.rss,
            rssAfter: after.rss,
            rssPeakBefore: before.rssPeak,
            rssPeakAfter: after.rssPeak,
            rssLoopMax: loopMax,
            footprintBefore: before.footprint,
            footprintAfter: after.footprint
        )
    }

    private static func sample(corpus: Phase1Corpus, draft: SampleDraft) -> Phase1Sample {
        let info = ProcessInfo.processInfo
        let walls = draft.series.walls.sorted()
        let cpus = draft.series.mainCpus.sorted()
        let fetches = draft.series.fetches.sorted()
        let computes = draft.series.computes.sorted()
        let meanWall = draft.series.walls.reduce(0, +) / Double(max(draft.series.walls.count, 1))
        let meanIn = Double(draft.series.inBlocks.reduce(0, +)) / Double(max(draft.series.inBlocks.count, 1))
        let meanOut = Double(draft.series.outBlocks.reduce(0, +)) / Double(max(draft.series.outBlocks.count, 1))
        var value = Phase1Sample()
        value.scenario = draft.scenario
        value.scale = corpus.graph.scale
        value.store = corpus.graph.store
        value.temperature = draft.temperature
        value.sampleCount = draft.sampleCount
        value.warmup = draft.warmup
        value.p50Ms = Phase1Clock.roundMs(Phase1Clock.percentile(walls, 0.50))
        value.p95Ms = Phase1Clock.roundMs(Phase1Clock.percentile(walls, 0.95))
        value.minMs = Phase1Clock.roundMs(walls.first ?? 0)
        value.maxMs = Phase1Clock.roundMs(walls.last ?? 0)
        value.meanMs = Phase1Clock.roundMs(meanWall)
        value.p50MainCpuMs = Phase1Clock.roundMs(Phase1Clock.percentile(cpus, 0.50))
        value.p50FetchWallMs = Phase1Clock.roundMs(Phase1Clock.percentile(fetches, 0.50))
        value.p50ComputeWallMs = Phase1Clock.roundMs(Phase1Clock.percentile(computes, 0.50))
        value.meanInBlock = Phase1Clock.roundMs(meanIn)
        value.meanOutBlock = Phase1Clock.roundMs(meanOut)
        value.fetchCalls = draft.last.fetchCalls
        value.resultRows = draft.last.rows
        value.repeatScans = draft.repeatScans
        value.extraCalls = draft.extraCalls
        value.rssBefore = draft.memory.rssBefore
        value.rssAfter = draft.memory.rssAfter
        value.rssPeakBefore = draft.memory.rssPeakBefore
        value.rssPeakAfter = draft.memory.rssPeakAfter
        value.rssLoopMax = draft.memory.rssLoopMax
        value.footprintBefore = draft.memory.footprintBefore
        value.footprintAfter = draft.memory.footprintAfter
        value.notes = draft.notes
        value.os = info.operatingSystemVersionString
        value.processorCount = info.processorCount
        value.physicalMemoryBytes = info.physicalMemory
        value.approximate = draft.approximate
        value.clock = clockKind
        value.logDirectory = Phase1Log.persistsFiles ? Phase1Log.combinedURL.deletingLastPathComponent().path : ""
        value.logIsolation = Phase1Log.isolationLabel
        return value
    }
}
