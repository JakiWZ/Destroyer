import Foundation

/// Svuota il Cestino dell'utente. ATTENZIONE: è **permanente** (non reversibile),
/// per questo è un'azione separata e confermata. Opera solo dentro `~/.Trash`.
public struct TrashEmptier {
    private let fileManager: FileManager
    private let trashURL: URL

    public init(fileManager: FileManager = .default, home: URL? = nil) {
        self.fileManager = fileManager
        self.trashURL = (home ?? fileManager.homeDirectoryForCurrentUser)
            .standardizedFileURL.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Byte attualmente nel Cestino.
    public func size() -> Int64 { FileScanner(fileManager: fileManager).size(of: trashURL) }

    /// Elimina definitivamente i contenuti del Cestino. Ritorna quanti elementi rimossi.
    /// Guardia: ogni elemento deve trovarsi STRETTAMENTE dentro ~/.Trash.
    @discardableResult
    public func empty() -> Int {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: trashURL, includingPropertiesForKeys: nil, options: []) else { return 0 }
        let trashComps = trashURL.pathComponents
        var removed = 0
        for entry in entries {
            let comps = entry.standardizedFileURL.pathComponents
            guard comps.count > trashComps.count,
                  Array(comps.prefix(trashComps.count)) == trashComps else { continue }
            if (try? fileManager.removeItem(at: entry)) != nil { removed += 1 }
        }
        return removed
    }
}
