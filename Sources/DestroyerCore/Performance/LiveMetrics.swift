import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(IOKit)
import IOKit.ps
#endif

/// Metriche di sistema in tempo reale: uso CPU (delta tra campioni) e batteria.
public final class LiveMetrics: @unchecked Sendable {

    private var prevTotal: UInt64 = 0
    private var prevIdle: UInt64 = 0
    private var prevNetBytes: UInt64 = 0
    private var prevNetTime: Date = .distantPast
    private let lock = NSLock()

    public init() {}

    public struct Network: Sendable {
        public let bytesPerSecDown: Double
        public let bytesPerSecUp: Double
    }

    public struct Battery: Sendable {
        public let level: Double      // 0–1
        public let isCharging: Bool
        public let isPresent: Bool
    }

    /// Uso CPU complessivo in [0,1]. Va chiamato periodicamente (usa il delta).
    public func cpuUsage() -> Double {
        #if canImport(Darwin)
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let total = user + system + idle + nice

        lock.lock(); defer { lock.unlock() }
        let totalDelta = total >= prevTotal ? total - prevTotal : 0
        let idleDelta = idle >= prevIdle ? idle - prevIdle : 0
        prevTotal = total; prevIdle = idle
        guard totalDelta > 0 else { return 0 }
        return min(1, max(0, Double(totalDelta - idleDelta) / Double(totalDelta)))
        #else
        return 0
        #endif
    }

    /// Throughput di rete complessivo (delta dei contatori delle interfacce).
    public func network() -> Network {
        #if canImport(Darwin)
        var totalBytes: UInt64 = 0
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0 else { return Network(bytesPerSecDown: 0, bytesPerSecUp: 0) }
        defer { freeifaddrs(ifap) }
        var ptr = ifap
        while let cur = ptr {
            if let addr = cur.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               let data = cur.pointee.ifa_data {
                let d = data.assumingMemoryBound(to: if_data.self)
                totalBytes += UInt64(d.pointee.ifi_ibytes) + UInt64(d.pointee.ifi_obytes)
            }
            ptr = cur.pointee.ifa_next
        }

        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let dt = now.timeIntervalSince(prevNetTime)
        let delta = totalBytes >= prevNetBytes ? totalBytes - prevNetBytes : 0
        prevNetBytes = totalBytes; prevNetTime = now
        guard dt > 0, dt < 30 else { return Network(bytesPerSecDown: 0, bytesPerSecUp: 0) }
        let rate = Double(delta) / dt
        // Non distinguiamo down/up in aggregato: riportiamo il totale come "down".
        return Network(bytesPerSecDown: rate, bytesPerSecUp: 0)
        #else
        return Network(bytesPerSecDown: 0, bytesPerSecUp: 0)
        #endif
    }

    /// Stato della batteria (se presente).
    public func battery() -> Battery {
        #if canImport(IOKit)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else { return Battery(level: 0, isCharging: false, isPresent: false) }

        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let state = desc[kIOPSPowerSourceStateKey] as? String
        let level = max > 0 ? Double(current) / Double(max) : 0
        return Battery(level: level, isCharging: state == kIOPSACPowerValue, isPresent: true)
        #else
        return Battery(level: 0, isCharging: false, isPresent: false)
        #endif
    }
}
