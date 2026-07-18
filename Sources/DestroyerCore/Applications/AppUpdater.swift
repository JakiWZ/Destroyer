import Foundation

/// Un'app con un aggiornamento disponibile (rilevata via Homebrew Cask).
public struct AppUpdate: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let currentVersion: String
    public let latestVersion: String

    public init(name: String, currentVersion: String, latestVersion: String) {
        self.name = name
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
    }
}

/// Rileva le app aggiornabili tramite **Homebrew Cask** (`brew outdated --cask`).
/// Onesto: copre solo le app gestite da Homebrew. Se brew non è installato, lo segnala.
public struct AppUpdater {

    public struct Result: Sendable {
        public let brewAvailable: Bool
        public let updates: [AppUpdate]
    }

    public init() {}

    public func check() -> Result {
        guard let brew = brewPath() else { return Result(brewAvailable: false, updates: []) }
        guard let json = runJSON([brew, "outdated", "--cask", "--greedy", "--json=v2"]) else {
            return Result(brewAvailable: true, updates: [])
        }
        let casks = (json["casks"] as? [[String: Any]]) ?? []
        let updates: [AppUpdate] = casks.compactMap { c in
            guard let name = c["name"] as? String else { return nil }
            let current = (c["installed_versions"] as? [String])?.first ?? (c["installed_version"] as? String) ?? "?"
            let latest = c["current_version"] as? String ?? "?"
            return AppUpdate(name: name, currentVersion: current, latestVersion: latest)
        }
        return Result(brewAvailable: true, updates: updates)
    }

    private func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.fileExists(atPath: $0) }
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
