import AppKit
import Darwin
import Testing

/// 仅 P 测试证据；闭包注入沿现有夹具方式覆盖 IO 失败，不引入日志服务。
@MainActor
final class ControlsPlatformEvidence {
    struct FileIO {
        var create: (URL) throws -> FileHandle = { url in
            let descriptor = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
            return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        }
        var encode: ([String: Any]) throws -> Data = {
            try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) + Data([10])
        }
        var write: (FileHandle, Data) throws -> Void = { try $0.write(contentsOf: $1) }
        var close: (FileHandle) throws -> Void = { try $0.close() }
    }

    let runID: String
    let sessionID = UUID().uuidString
    let processID = ProcessInfo.processInfo.processIdentifier
    let processIdentity: String
    let url: URL
    private(set) var sequence = 0
    private(set) var failure: String?
    private(set) var closed = false
    private(set) var handle: FileHandle?
    private let io: FileIO
    private let reportFailure: (String) -> Void
    private let output: (String) -> Void
    private var attempted = false

    init(runID: String? = nil, io: FileIO = FileIO(),
         reportFailure: @escaping (String) -> Void = { Issue.record(Comment(rawValue: $0)) },
         output: @escaping (String) -> Void = { print($0) }) {
        let supplied = runID ?? ProcessInfo.processInfo.environment["AREACHAIN_CONTROLS_RUN_ID"]
        self.runID = supplied.flatMap(UUID.init(uuidString:))?.uuidString ?? UUID().uuidString
        self.io = io
        self.reportFailure = reportFailure
        self.output = output
        var info = kinfo_proc()
        var length = MemoryLayout<kinfo_proc>.size
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, processID]
        let result = sysctl(&mib, u_int(mib.count), &info, &length, nil, 0)
        let start = info.kp_proc.p_starttime
        processIdentity = result == 0 ? "\(processID):\(start.tv_sec):\(start.tv_usec)" : "unknown"
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("areachain-controls-P-\(self.runID)-\(sessionID).jsonl")
    }

    func start() {
        guard !attempted else { return }
        attempted = true
        output("CONTROLS_P_BEGIN \(runID) \(sessionID) \(url.path)")
        do { handle = try io.create(url) }
        catch { fail("create") }
        if processIdentity == "unknown" { fail("process-identity") }
    }

    @discardableResult
    func record(_ kind: String, _ values: [String: Any] = [:]) -> Int {
        guard attempted, !closed else { return sequence }
        sequence += 1
        var row = values
        row["kind"] = kind
        row["runID"] = runID
        row["sessionID"] = sessionID
        row["pid"] = processID
        row["processIdentity"] = processIdentity
        row["sequence"] = sequence
        row["wallTime"] = Date().timeIntervalSince1970
        row["uptime"] = ProcessInfo.processInfo.systemUptime
        guard failure == nil, let handle else { return sequence }
        let data: Data
        do { data = try io.encode(row) }
        catch { fail("serialize"); return sequence }
        do { try io.write(handle, data) }
        catch { fail("write"); return sequence }
        output("CONTROLS_P \(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines))")
        return sequence
    }

    func finish() {
        guard attempted, !closed else { return }
        closed = true
        var fileClosed = false
        if let handle {
            do { try io.close(handle); fileClosed = true }
            catch {
                fail("close")
                // 注入失败也要尝试释放真实描述符；成功不能撤销首次失败。
                do { try handle.close() } catch { fail("close-release") }
            }
        }
        handle = nil
        output("CONTROLS_P_END \(runID) \(sessionID) fileClosed=\(fileClosed) complete=\(fileClosed && failure == nil)")
    }

    private func fail(_ stage: String) {
        guard failure == nil else { return }
        failure = stage
        let message = "CONTROLS_P_FAILURE \(runID) \(sessionID) stage=\(stage) evidence=incomplete"
        output(message)
        reportFailure(message)
    }
}
