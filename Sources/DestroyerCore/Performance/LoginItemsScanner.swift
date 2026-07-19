import Foundation

/// Un elemento che parte automaticamente (LaunchAgent/Daemon).
public struct LoginItem: Identifiable, Sendable {
    /// Impatto stimato sull'avvio/risorse.
    public enum Impact: Int, Sendable { case low = 0, medium, high
        public var label: String { self == .high ? "Alto" : (self == .medium ? "Medio" : "Basso") }
    }

    public var id: URL { plistURL }
    public let label: String
    public let plistURL: URL
    public let programPath: String?
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public let isSystem: Bool
    public let impact: Impact

    public init(label: String, plistURL: URL, programPath: String?, runAtLoad: Bool,
                keepAlive: Bool, isSystem: Bool, impact: Impact) {
        self.label = label
        self.plistURL = plistURL
        self.programPath = programPath
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.isSystem = isSystem
        self.impact = impact
    }
}

/// Enumera gli elementi di avvio (login/background items) nelle posizioni standard.
/// La rimozione avviene poi via Cestino (`launchctl` bootout + guardia `SafePaths`).
public struct LoginItemsScanner {
    private let fileManager: FileManager
    private let home: URL

    public init(fileManager: FileManager = .default, home: URL? = nil) {
        self.fileManager = fileManager
        self.home = (home ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
    }

    public func scan() -> [LoginItem] {
        let dirs: [(URL, Bool)] = [
            (home.appendingPathComponent("Library/LaunchAgents", isDirectory: true), false),
            (URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), true),
            (URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), true)
        ]
        var items: [LoginItem] = []
        for (dir, system) in dirs {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for plist in entries where plist.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: plist),
                      let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                else { continue }
                let label = (dict["Label"] as? String) ?? plist.deletingPathExtension().lastPathComponent
                let program = (dict["Program"] as? String) ?? (dict["ProgramArguments"] as? [String])?.first
                let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
                let keepAlive: Bool = {
                    if let b = dict["KeepAlive"] as? Bool { return b }
                    return dict["KeepAlive"] != nil   // dizionario di condizioni = mantiene vivo
                }()
                // Impatto: sempre-attivo (RunAtLoad+KeepAlive) = alto; solo avvio = medio; on-demand = basso.
                let impact: LoginItem.Impact = (runAtLoad && keepAlive) ? .high : (runAtLoad ? .medium : .low)
                items.append(LoginItem(label: label, plistURL: plist, programPath: program,
                                       runAtLoad: runAtLoad, keepAlive: keepAlive, isSystem: system, impact: impact))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
