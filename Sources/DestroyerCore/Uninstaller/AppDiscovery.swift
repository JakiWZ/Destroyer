import Foundation

/// Individua le app installate e legge i metadati di un bundle .app.
public struct AppDiscovery {

    private let fileManager: FileManager
    private let scanner: FileScanner
    private let searchRoots: [URL]

    public init(
        fileManager: FileManager = .default,
        searchRoots: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
        self.searchRoots = searchRoots ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    /// Elenca le app .app presenti nelle root di ricerca (livello immediato).
    public func installedApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        for root in searchRoots {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                if let app = app(at: entry) { apps.append(app) }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Costruisce un `InstalledApp` da un bundle .app leggendone l'Info.plist.
    public func app(at bundleURL: URL) -> InstalledApp? {
        guard bundleURL.pathExtension == "app",
              fileManager.fileExists(atPath: bundleURL.path) else { return nil }

        let info = infoPlist(for: bundleURL)
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let bundleID = info?["CFBundleIdentifier"] as? String

        return InstalledApp(
            bundleURL: bundleURL,
            name: name,
            bundleIdentifier: bundleID,
            sizeBytes: scanner.size(of: bundleURL)
        )
    }

    private func infoPlist(for bundleURL: URL) -> [String: Any]? {
        let plistURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }
        return obj as? [String: Any]
    }
}
