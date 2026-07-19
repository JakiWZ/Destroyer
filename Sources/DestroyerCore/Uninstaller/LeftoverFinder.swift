import Foundation

/// Dato un'app, individua i file residui nelle directory Library note.
/// Matching: prima per **bundle identifier** (preciso, selezionato di default),
/// poi per **nome app** (fuzzy, NON selezionato di default per prudenza).
public struct LeftoverFinder {

    private let fileManager: FileManager
    private let scanner: FileScanner
    private let home: URL

    public init(
        fileManager: FileManager = .default,
        home: URL? = nil
    ) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
        self.home = (home ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
    }

    /// Directory da ispezionare per ogni categoria.
    private struct Location {
        let url: URL
        let category: LeftoverCategory
    }

    private func locations() -> [Location] {
        let lib = home.appendingPathComponent("Library", isDirectory: true)
        func h(_ c: String) -> URL { lib.appendingPathComponent(c, isDirectory: true) }
        func s(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }
        return [
            // Aree utente (~/Library)
            Location(url: h("Caches"),                   category: .caches),
            Location(url: h("Preferences"),              category: .preferences),
            Location(url: h("Application Support"),      category: .appSupport),
            Location(url: h("Containers"),               category: .containers),
            Location(url: h("Group Containers"),         category: .groupContainers),
            Location(url: h("Logs"),                     category: .logs),
            Location(url: h("LaunchAgents"),             category: .launchAgents),
            Location(url: h("Saved Application State"),  category: .savedState),
            Location(url: h("Application Scripts"),      category: .applicationScripts),
            Location(url: h("HTTPStorages"),             category: .httpStorages),
            Location(url: h("WebKit"),                   category: .webKit),
            Location(url: h("Cookies"),                  category: .cookies),
            // Plugin e componenti (utente)
            Location(url: h("PreferencePanes"),          category: .preferencePanes),
            Location(url: h("QuickLook"),                category: .quickLook),
            Location(url: h("Spotlight"),                category: .spotlight),
            Location(url: h("Services"),                 category: .services),
            Location(url: h("Screen Savers"),            category: .screenSavers),
            Location(url: h("Internet Plug-Ins"),        category: .internetPlugins),
            // Aree di sistema (/Library) — root, richiedono autorizzazione admin
            Location(url: s("/Library/LaunchAgents"),          category: .launchAgents),
            Location(url: s("/Library/LaunchDaemons"),         category: .launchDaemons),
            Location(url: s("/Library/PrivilegedHelperTools"), category: .privilegedHelper),
            Location(url: s("/Library/Application Support"),   category: .appSupport),
            Location(url: s("/Library/Caches"),                category: .caches),
            Location(url: s("/Library/Logs"),                  category: .logs),
            Location(url: s("/Library/Preferences"),           category: .preferences),
            Location(url: s("/Library/PreferencePanes"),       category: .preferencePanes),
            Location(url: s("/Library/QuickLook"),             category: .quickLook),
            Location(url: s("/Library/Spotlight"),             category: .spotlight),
            Location(url: s("/Library/Services"),              category: .services),
            Location(url: s("/Library/Screen Savers"),         category: .screenSavers),
            Location(url: s("/Library/Internet Plug-Ins"),     category: .internetPlugins)
        ]
    }

    /// Trova i residui per l'app data. Non include il bundle .app stesso.
    public func findLeftovers(for app: InstalledApp) -> [LeftoverItem] {
        let bundleID = app.bundleIdentifier?.lowercased()
        let nameToken = normalizedNameToken(app.name)

        var items: [LeftoverItem] = []
        var seen = Set<String>()

        for location in locations() {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: location.url,
                includingPropertiesForKeys: nil,
                options: []
            ) else { continue }

            for entry in entries {
                let lower = entry.lastPathComponent.lowercased()
                let byBundle = bundleID.map { lower.contains($0) } ?? false
                let byName = !nameToken.isEmpty && lower.contains(nameToken)
                guard byBundle || byName else { continue }

                let key = entry.standardizedFileURL.path
                guard seen.insert(key).inserted else { continue }

                var item = LeftoverItem(
                    url: entry,
                    category: location.category,
                    sizeBytes: scanner.size(of: entry),
                    isSystemProtected: false,
                    requiresAuthorization: needsAuthorization(entry)
                )
                // Prudenza: i match solo-per-nome partono deselezionati.
                item.isSelected = byBundle
                items.append(item)
            }
        }
        return items
    }

    /// Un item richiede autorizzazione admin se la sua directory contenitrice non è
    /// scrivibile dall'utente corrente (tipico dei file di sistema in /Library di root).
    private func needsAuthorization(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().path
        return !fileManager.isWritableFile(atPath: parent)
    }

    /// Normalizza il nome app in un token per il matching fuzzy:
    /// minuscolo e senza spazi/simboli. Token troppo corti (<3) vengono scartati
    /// per evitare falsi positivi.
    private func normalizedNameToken(_ name: String) -> String {
        let token = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return token.count >= 3 ? token : ""
    }
}
