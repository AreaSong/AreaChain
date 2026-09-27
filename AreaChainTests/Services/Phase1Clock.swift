import Darwin
import Foundation

/// 一次探针：wall、当前线程 CPU、进程 rusage、RSS/峰值/phys_footprint。
struct Phase1Probe {
    var wall: Double
    var threadCpuMs: Double
    var userCpuMs: Double
    var systemCpuMs: Double
    var inBlock: Int64
    var outBlock: Int64
    var rss: UInt64
    var rssPeak: UInt64
    var footprint: UInt64
}

struct Phase1Timing {
    var wallMs: Double = 0
    var mainCpuMs: Double = 0
    var userCpuMs: Double = 0
    var systemCpuMs: Double = 0
    var inBlock: Int64 = 0
    var outBlock: Int64 = 0
}

struct Phase1MemoryMark {
    var rssBefore: UInt64
    var rssAfter: UInt64
    var rssPeakBefore: UInt64
    var rssPeakAfter: UInt64
    var rssLoopMax: UInt64
    var footprintBefore: UInt64
    var footprintAfter: UInt64
}

enum Phase1Clock {
    static func probe() -> Phase1Probe {
        let usage = currentUsage()
        let vmInfo = currentVM()
        return Phase1Probe(
            wall: ProcessInfo.processInfo.systemUptime,
            threadCpuMs: currentThreadCpuMs(),
            userCpuMs: usage.userMs,
            systemCpuMs: usage.systemMs,
            inBlock: usage.inBlock,
            outBlock: usage.outBlock,
            rss: vmInfo.rss,
            rssPeak: vmInfo.rssPeak,
            footprint: vmInfo.footprint
        )
    }

    static func millis<T>(_ work: () throws -> T) rethrows -> (T, Phase1Timing) {
        let start = probe()
        let value = try work()
        return (value, delta(start, probe()))
    }

    static func delta(_ start: Phase1Probe, _ end: Phase1Probe) -> Phase1Timing {
        Phase1Timing(
            wallMs: (end.wall - start.wall) * 1_000,
            mainCpuMs: max(0, end.threadCpuMs - start.threadCpuMs),
            userCpuMs: max(0, end.userCpuMs - start.userCpuMs),
            systemCpuMs: max(0, end.systemCpuMs - start.systemCpuMs),
            inBlock: max(0, end.inBlock - start.inBlock),
            outBlock: max(0, end.outBlock - start.outBlock)
        )
    }

    static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int(ceil(fraction * Double(sorted.count))) - 1))
        return sorted[index]
    }

    static func roundMs(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }

    static func rss() -> UInt64 {
        currentVM().rss
    }

    private struct Usage {
        var userMs: Double
        var systemMs: Double
        var inBlock: Int64
        var outBlock: Int64
    }

    private struct VMInfo {
        var rss: UInt64
        var rssPeak: UInt64
        var footprint: UInt64
    }

    private static func currentUsage() -> Usage {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Usage(
            userMs: timeValMs(usage.ru_utime),
            systemMs: timeValMs(usage.ru_stime),
            inBlock: Int64(usage.ru_inblock),
            outBlock: Int64(usage.ru_oublock)
        )
    }

    private static func currentThreadCpuMs() -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(mach_thread_self(), thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return 0 }
        return timeValueMs(info.user_time) + timeValueMs(info.system_time)
    }

    private static func currentVM() -> VMInfo {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS {
            return VMInfo(
                rss: UInt64(info.resident_size),
                rssPeak: UInt64(info.resident_size_peak),
                footprint: UInt64(info.phys_footprint)
            )
        }
        let resident = basicResident()
        return VMInfo(rss: resident, rssPeak: resident, footprint: 0)
    }

    private static func basicResident() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }

    private static func timeValMs(_ value: timeval) -> Double {
        Double(value.tv_sec) * 1_000 + Double(value.tv_usec) / 1_000
    }

    private static func timeValueMs(_ value: time_value) -> Double {
        Double(value.seconds) * 1_000 + Double(value.microseconds) / 1_000
    }
}
