import Foundation

/// Utility di filesystem: esistenza e calcolo dimensioni su disco.
public struct FileScanner {

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Dimensione totale in byte di un file o cartella (ricorsiva).
    /// Ritorna 0 per path inesistenti o non leggibili.
    public func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return fileSize(url)
        }

        var total: Int64 = 0
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let child as URL in enumerator {
            total += fileSize(child)
        }
        return total
    }

    private func fileSize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        if let logical = values.fileSize { return Int64(logical) }
        return 0
    }

    public func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
