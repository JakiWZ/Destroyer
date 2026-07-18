import Foundation

/// Voce di junk (una sottocartella di cache/log o un gruppo).
public struct JunkItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let sizeBytes: Int64
    public var isSelected: Bool

    public init(id: UUID = UUID(), url: URL, sizeBytes: Int64, isSelected: Bool = true) {
        self.id = id
        self.url = url
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
    }
}

/// Gruppo di junk per categoria (Cache utente, Log utente, Cestino).
public struct JunkGroup: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let systemImage: String
    public var items: [JunkItem]
    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }
    public var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }
}

/// Scansione junk sicura: solo aree utente reversibili (Cestino). Nessun file di sistema.
public struct JunkScanner {
    private let fileManager: FileManager
    private let scanner: FileScanner
    private let home: URL

    public init(fileManager: FileManager = .default, home: URL? = nil) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
        self.home = (home ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
    }

    public func scan() -> [JunkGroup] {
        let lib = home.appendingPathComponent("Library", isDirectory: true)
        var groups: [JunkGroup] = []

        if let caches = groupFromChildren(
            of: lib.appendingPathComponent("Caches", isDirectory: true),
            name: "Cache applicazioni", icon: "shippingbox"
        ) { groups.append(caches) }

        if let logs = groupFromChildren(
            of: lib.appendingPathComponent("Logs", isDirectory: true),
            name: "Log", icon: "doc.text"
        ) { groups.append(logs) }

        // Junk di sviluppo (Xcode) — ricreabile, sicuro da rimuovere.
        let dev = lib.appendingPathComponent("Developer", isDirectory: true)
        for (rel, name) in [
            ("Xcode/DerivedData", "Xcode DerivedData"),
            ("Xcode/Archives", "Xcode Archives"),
            ("Xcode/iOS DeviceSupport", "iOS DeviceSupport"),
            ("CoreSimulator/Caches", "Simulator Caches")
        ] {
            if let g = groupFromChildren(of: dev.appendingPathComponent(rel, isDirectory: true),
                                         name: name, icon: "hammer") {
                groups.append(g)
            }
        }

        return groups
    }

    /// Crea un gruppo dai figli immediati di una directory (ogni figlio = un item).
    private func groupFromChildren(of dir: URL, name: String, icon: String) -> JunkGroup? {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ), !entries.isEmpty else { return nil }

        let items = entries.compactMap { url -> JunkItem? in
            let size = scanner.size(of: url)
            return size > 0 ? JunkItem(url: url, sizeBytes: size) : nil
        }.sorted { $0.sizeBytes > $1.sizeBytes }

        return items.isEmpty ? nil : JunkGroup(name: name, systemImage: icon, items: items)
    }
}
