import Foundation
import CryptoKit

/// Un file individuato dagli scanner "file grandi/vecchi" o "duplicati".
public struct ScannedFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let sizeBytes: Int64
    public let modified: Date
    public var isSelected: Bool

    public init(url: URL, sizeBytes: Int64, modified: Date, isSelected: Bool = false) {
        self.url = url
        self.sizeBytes = sizeBytes
        self.modified = modified
        self.isSelected = isSelected
    }
}

/// Gruppo di file duplicati (stesso contenuto).
public struct DuplicateGroup: Identifiable, Sendable {
    public let id = UUID()
    public let hashPrefix: String
    public var files: [ScannedFile]
    public var sizeBytes: Int64 { files.first?.sizeBytes ?? 0 }
    /// Spazio recuperabile mantenendo una sola copia.
    public var reclaimableBytes: Int64 { Int64(max(0, files.count - 1)) * sizeBytes }
}

/// Scanner per "file grandi e vecchi" e "duplicati". Sola lettura; la rimozione avviene
/// poi via Cestino (guardia `SafePaths`). Attraversa solo cartelle utente sicure.
public struct FileInsightScanner {
    private let fileManager: FileManager
    private let roots: [URL]

    public init(fileManager: FileManager = .default, home: URL? = nil, roots: [URL]? = nil) {
        self.fileManager = fileManager
        let h = (home ?? fileManager.homeDirectoryForCurrentUser)
        self.roots = roots ?? ["Downloads", "Documents", "Desktop", "Movies"].map {
            h.appendingPathComponent($0, isDirectory: true)
        }
    }

    /// Risultato combinato di una **singola** enumerazione (grandi/vecchi + duplicati).
    public struct Insight: Sendable {
        public let large: [ScannedFile]
        public let duplicates: [DuplicateGroup]
    }

    /// Analizza in **un solo passaggio** sul filesystem (evita di enumerare due volte).
    public func analyze(minLargeBytes: Int64 = 100 * 1024 * 1024,
                        olderThanDays: Int = 180,
                        minDuplicateBytes: Int64 = 1 * 1024 * 1024) -> Insight {
        let files = allFiles()
        return Insight(
            large: largeOrOld(in: files, minBytes: minLargeBytes, olderThanDays: olderThanDays),
            duplicates: duplicates(in: files, minBytes: minDuplicateBytes)
        )
    }

    /// File più grandi di `minBytes` OPPURE più vecchi di `olderThanDays`.
    public func largeOrOld(minBytes: Int64 = 100 * 1024 * 1024, olderThanDays: Int = 180) -> [ScannedFile] {
        largeOrOld(in: allFiles(), minBytes: minBytes, olderThanDays: olderThanDays)
    }

    /// Gruppi di duplicati (soglia minima di dimensione per ridurre rumore e lavoro).
    public func duplicates(minBytes: Int64 = 0) -> [DuplicateGroup] {
        duplicates(in: allFiles(), minBytes: minBytes)
    }

    // MARK: - Implementazioni su una lista già enumerata

    private func largeOrOld(in files: [ScannedFile], minBytes: Int64, olderThanDays: Int) -> [ScannedFile] {
        let cutoff = Date().addingTimeInterval(-Double(olderThanDays) * 86_400)
        return files.filter { f in
            (f.sizeBytes >= minBytes) || (f.modified < cutoff && f.sizeBytes >= 5 * 1024 * 1024)
        }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func duplicates(in files: [ScannedFile], minBytes: Int64) -> [DuplicateGroup] {
        let maxHashBytes: Int64 = 2 * 1024 * 1024 * 1024   // non leggere file enormi
        var bySize: [Int64: [ScannedFile]] = [:]
        for f in files where f.sizeBytes >= minBytes && f.sizeBytes <= maxHashBytes {
            bySize[f.sizeBytes, default: []].append(f)
        }
        var groups: [DuplicateGroup] = []
        for (_, candidates) in bySize where candidates.count > 1 {
            var byHash: [String: [ScannedFile]] = [:]
            for f in candidates {
                guard let h = hash(of: f.url) else { continue }
                byHash[h, default: []].append(f)
            }
            for (h, dupes) in byHash where dupes.count > 1 {
                var sorted = dupes.sorted { $0.modified < $1.modified }
                for i in sorted.indices { sorted[i].isSelected = i > 0 }  // tieni il più vecchio
                groups.append(DuplicateGroup(hashPrefix: String(h.prefix(12)), files: sorted))
            }
        }
        return groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    // MARK: - Helper

    private func allFiles() -> [ScannedFile] {
        var out: [ScannedFile] = []
        for root in roots {
            guard let en = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in en {
                let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
                guard v?.isRegularFile == true else { continue }
                let size = Int64(v?.fileSize ?? 0)
                let mod = v?.contentModificationDate ?? .distantPast
                out.append(ScannedFile(url: url, sizeBytes: size, modified: mod))
            }
        }
        return out
    }

    private func hash(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
