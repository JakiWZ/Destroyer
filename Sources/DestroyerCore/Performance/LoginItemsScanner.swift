import Foundation

/// Un elemento che parte automaticamente (LaunchAgent/Daemon).
public struct LoginItem: Identifiable, Sendable {
    public var id: URL { plistURL }
    public let label: String
    public let plistURL: URL
    public let programPath: String?
    public let runAtLoad: Bool
    public let isSystem: Bool

    public init(label: String, plistURL: URL, programPath: String?, runAtLoad: Bool, isSystem: Bool) {
        self.label = label
        self.plistURL = plistURL
        self.programPath = programPath
        self.runAtLoad = runAtLoad
        self.isSystem = isSystem
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
                items.append(LoginItem(label: label, plistURL: plist, programPath: program,
                                       runAtLoad: runAtLoad, isSystem: system))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
