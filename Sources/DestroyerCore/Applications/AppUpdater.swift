import Foundation

/// Da dove proviene l'app / come si aggiorna.
public enum UpdateSource: String, Sendable {
    case homebrew   // gestita da Homebrew Cask
    case appStore   // installata dal Mac App Store
    case sparkle    // app da internet con auto-update Sparkle

    public var label: String {
        switch self {
        case .homebrew: return "Homebrew"
        case .appStore: return "App Store"
        case .sparkle:  return "Internet"
        }
    }
}

/// Un'app con un aggiornamento disponibile.
public struct AppUpdate: Identifiable, Sendable {
    public var id: String { name + source.rawValue }
    public let name: String
    public let currentVersion: String
    public let latestVersion: String
    public let source: UpdateSource
    /// Dove aggiornare (pagina App Store / release), se disponibile.
    public let url: URL?

    public init(name: String, currentVersion: String, latestVersion: String,
                source: UpdateSource, url: URL? = nil) {
        self.name = name
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.source = source
        self.url = url
    }
}

/// Rileva le app aggiornabili da **tre fonti**: Homebrew Cask, Mac App Store
/// (via API pubblica iTunes) e app da internet con **Sparkle** (via appcast).
/// Le app senza alcun meccanismo di aggiornamento non sono rilevabili (nessun registro centrale).
public struct AppUpdater {

    public struct Result: Sendable {
        public let brewAvailable: Bool
        public let updates: [AppUpdate]
    }

    private let fileManager: FileManager
    private let session: URLSession

    public init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
    }

    /// Controllo completo (Homebrew + App Store + Sparkle). Async per le richieste di rete.
    public func checkAll() async -> Result {
        let brew = checkHomebrew()
        let installed = await checkInstalledApps()
        return Result(brewAvailable: brew.brewAvailable, updates: brew.updates + installed)
    }

    // MARK: - Homebrew (sync)

    private func checkHomebrew() -> (brewAvailable: Bool, updates: [AppUpdate]) {
        guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: { fileManager.fileExists(atPath: $0) }) else {
            return (false, [])
        }
        guard let json = runJSON([brew, "outdated", "--cask", "--greedy", "--json=v2"]),
              let casks = json["casks"] as? [[String: Any]] else { return (true, []) }
        let updates = casks.compactMap { c -> AppUpdate? in
            guard let name = c["name"] as? String else { return nil }
            let current = (c["installed_versions"] as? [String])?.first ?? "?"
            let latest = c["current_version"] as? String ?? "?"
            return AppUpdate(name: name, currentVersion: current, latestVersion: latest, source: .homebrew)
        }
        return (true, updates)
    }

    // MARK: - App installate: App Store + Sparkle

    private func checkInstalledApps() async -> [AppUpdate] {
        let dirs = [URL(fileURLWithPath: "/Applications"),
                    fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var results: [AppUpdate] = []
        for dir in dirs {
            guard let apps = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for app in apps where app.pathExtension == "app" {
                if let u = await checkApp(app) { results.append(u) }
            }
        }
        return results
    }

    private func checkApp(_ bundle: URL) async -> AppUpdate? {
        guard let info = infoPlist(bundle) else { return nil }
        let name = (info["CFBundleName"] as? String) ?? bundle.deletingPathExtension().lastPathComponent
        let current = (info["CFBundleShortVersionString"] as? String) ?? "?"

        // Mac App Store: presenza della ricevuta MAS.
        let receipt = bundle.appendingPathComponent("Contents/_MASReceipt/receipt")
        if fileManager.fileExists(atPath: receipt.path),
           let bundleID = info["CFBundleIdentifier"] as? String {
            return await checkAppStore(name: name, bundleID: bundleID, current: current)
        }

        // Sparkle: presenza di SUFeedURL.
        if let feed = (info["SUFeedURL"] as? String).flatMap(URL.init) {
            return await checkSparkle(name: name, feed: feed, current: current)
        }
        return nil
    }

    private func checkAppStore(name: String, bundleID: String, current: String) async -> AppUpdate? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else { return nil }
        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let latest = first["version"] as? String else { return nil }
        guard isNewer(latest, than: current) else { return nil }
        let page = (first["trackViewUrl"] as? String).flatMap(URL.init)
        return AppUpdate(name: name, currentVersion: current, latestVersion: latest, source: .appStore, url: page)
    }

    private func checkSparkle(name: String, feed: URL, current: String) async -> AppUpdate? {
        guard let (data, _) = try? await session.data(from: feed),
              let xml = String(data: data, encoding: .utf8) else { return nil }
        // Estrae tutte le versioni dall'appcast e prende la più alta.
        let versions = matches(in: xml, pattern: "sparkle:shortVersionString=\"([^\"]+)\"")
            + matches(in: xml, pattern: "<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>")
        guard let latest = versions.max(by: { isNewer($1, than: $0) }),
              isNewer(latest, than: current) else { return nil }
        return AppUpdate(name: name, currentVersion: current, latestVersion: latest, source: .sparkle, url: feed)
    }

    // MARK: - Helper

    private func infoPlist(_ bundle: URL) -> [String: Any]? {
        let url = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        return obj as? [String: Any]
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// Confronto versioni "a.b.c" (numerico dove possibile).
    func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
        let pb = b.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func runJSON(_ argv: [String]) -> [String: Any]? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
