#if AREACHAIN_QA
import AppKit
import Darwin
import Testing
@testable import AreaChain

/// 每一步同步保存无内容指标；超时进程结束后仍能区分准备成本与最后完成的操作。
@MainActor final class CommandTextPrototypeJournal {
    let engine: CommandTextPrototype
    let host: String
    let bytes: Int
    let paragraphs: Bool
    let deadline: TimeInterval
    let experimentStart: TimeInterval
    let directory: URL
    private let file: FileHandle
    private var phases: [String: Double] = [:]

    init() throws {
        let env = ProcessInfo.processInfo.environment
        try #require(AppStartup.policy == .testing && AppStartup.compiledForQA)
        engine = try #require(env["AREACHAIN_CM2_ENGINE"].flatMap(CommandTextPrototype.init(rawValue:)))
        host = try #require(env["AREACHAIN_CM2_HOST"])
        bytes = try #require(env["AREACHAIN_CM2_BYTES"].flatMap(Int.init))
        paragraphs = env["AREACHAIN_CM2_PARAGRAPHS"] == "1"
        try #require(["probe", "standard", "compact"].contains(host) && [1_024, 65_536, 1_048_576].contains(bytes))
        deadline = try #require(env["AREACHAIN_CM2_DEADLINE"].flatMap(Double.init))
        experimentStart = try #require(env["AREACHAIN_CM2_EXPERIMENT_START"].flatMap(Double.init))
        let run = try #require(env["AREACHAIN_CM2_RUN_ID"])
        try #require(UUID(uuidString: run) != nil && Bundle.main.bundleIdentifier == CommandTextQAWindowLease.bundle)
        directory = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "tmp/CM2Runner/" + run)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "metrics.jsonl")
        try Data().write(to: url, options: .withoutOverwriting)
        file = try FileHandle(forWritingTo: url)
        CommandTextTiming.observe = { [weak self] phase, value in
            MainActor.assumeIsolated { self?.phases[phase, default: 0] += value }
        }
        try record("testEntered", values: ["runnerToTestMS": (Date().timeIntervalSince1970 - experimentStart) * 1_000,
            "os": ProcessInfo.processInfo.operatingSystemVersionString, "coldTestProcess": true,
            "configuration": "Debug", "cpuCount": ProcessInfo.processInfo.processorCount])
    }

    deinit { try? file.close() }

    func resetPhases() { phases.removeAll() }

    func record(_ operation: String, values: [String: Any] = [:]) throws {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        var row: [String: Any] = ["operation": operation, "engine": engine.rawValue, "host": host,
            "bytes": bytes, "paragraphs": paragraphs, "sinceExperimentMS": (Date().timeIntervalSince1970 - experimentStart) * 1_000,
            "peakRSSBytes": usage.ru_maxrss, "phaseTimesAreNested": true, "phasesMS": phases]
        row.merge(values) { _, value in value }
        var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        data.append(0x0a)
        try file.write(contentsOf: data)
        try file.synchronize()
    }

    @discardableResult func measure<Value>(_ operation: String, values: [String: Any] = [:],
                                          _ body: () throws -> Value) throws -> Value {
        try #require(Date().timeIntervalSince1970 < deadline)
        try record(operation + ".start", values: values)
        phases.removeAll()
        let start = ContinuousClock.now
        let result = try body()
        var metadata = values
        metadata["totalMS"] = CommandTextPrototypeChecks.milliseconds(start)
        metadata["phasesMS"] = phases
        try record(operation, values: metadata)
        return result
    }

    func body() -> String {
        let block = paragraphs ? String(repeating: "中a🙂", count: 127) + "中\n🙂" : String(repeating: "中a🙂", count: 128)
        return String(repeating: block, count: bytes / 1_024)
    }
}
#endif
