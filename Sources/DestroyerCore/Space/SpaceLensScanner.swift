import Foundation

/// Voce della mappa spazio: un file o cartella con la sua dimensione su disco.
public struct SpaceEntry: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let sizeBytes: Int64
    public let isDirectory: Bool

    public init(url: URL, name: String, sizeBytes: Int64, isDirectory: Bool) {
        self.url = url
        self.name = name
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }
}

/// "Space Lens": scompone una cartella nei suoi figli ordinati per dimensione,
/// per una mappa visuale del disco (treemap/barre). Sola lettura.
public struct SpaceLensScanner {
    private let fileManager: FileManager
    private let scanner: FileScanner

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
    }

    /// Figli immediati di `root` con dimensione totale (ricorsiva), ordinati decrescente.
    public func breakdown(of root: URL) -> [SpaceEntry] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [SpaceEntry] = []
        for url in entries {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size = scanner.size(of: url)
            guard size > 0 else { continue }
            result.append(SpaceEntry(url: url, name: url.lastPathComponent, sizeBytes: size, isDirectory: isDir))
        }
        return result.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
