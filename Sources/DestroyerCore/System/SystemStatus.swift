import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Istantanea (read-only) dello stato del Mac per la dashboard.
public struct SystemSnapshot: Sendable {
    public let diskTotalBytes: Int64
    public let diskAvailableBytes: Int64
    public let ramTotalBytes: Int64
    public let ramUsedBytes: Int64
    public let trashBytes: Int64

    public var diskUsedBytes: Int64 { max(0, diskTotalBytes - diskAvailableBytes) }

    /// Frazione di disco usata, in [0, 1].
    public var diskUsedFraction: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return clamp(Double(diskUsedBytes) / Double(diskTotalBytes))
    }

    /// Frazione di RAM usata, in [0, 1].
    public var ramUsedFraction: Double {
        guard ramTotalBytes > 0 else { return 0 }
        return clamp(Double(ramUsedBytes) / Double(ramTotalBytes))
    }

    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}

/// Legge in sola lettura lo stato del sistema. Nessuna scrittura, nessun rischio.
public struct SystemStatus {

    private let fileManager: FileManager
    private let scanner: FileScanner

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
    }

    public func snapshot() -> SystemSnapshot {
        let (total, available) = diskCapacity()
        let ramTotal = Int64(ProcessInfo.processInfo.physicalMemory)
        return SystemSnapshot(
            diskTotalBytes: total,
            diskAvailableBytes: available,
            ramTotalBytes: ramTotal,
            ramUsedBytes: ramUsed(total: ramTotal),
            trashBytes: trashSize()
        )
    }

    // MARK: - Disco

    private func diskCapacity() -> (total: Int64, available: Int64) {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return (0, 0) }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage {
            available = important
        } else {
            available = Int64(values.volumeAvailableCapacity ?? 0)
        }
        return (total, available)
    }

    // MARK: - RAM

    private func ramUsed(total: Int64) -> Int64 {
        #if canImport(Darwin)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        var pageSize: vm_size_t = 0
        host_page_size(host, &pageSize)
        let page = Int64(pageSize)

        // "Usata" = attive + wired + compresse (esclude free e inactive/purgeable).
        let active = Int64(stats.active_count) * page
        let wired = Int64(stats.wire_count) * page
        let compressed = Int64(stats.compressor_page_count) * page
        let used = active + wired + compressed
        return min(used, total)
        #else
        return 0
        #endif
    }

    // MARK: - Cestino

    private func trashSize() -> Int64 {
        let trash = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
        return scanner.size(of: trash)
    }
}
