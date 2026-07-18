import Foundation

/// Pianifica una scansione in background tramite un **LaunchAgent utente**, così parte
/// anche quando l'app è chiusa (a differenza del timer in-app). Nessun privilegio admin:
/// è un agent a livello utente in `~/Library/LaunchAgents`.
///
/// L'agent apre l'app in background con l'argomento `--scheduled-scan`, che avvia uno Smart Scan.
public struct BackgroundScheduler {

    private let fileManager: FileManager
    private let label = "io.github.destroyer.scheduledscan"
    private let bundlePath: String

    public init(fileManager: FileManager = .default, bundlePath: String = Bundle.main.bundlePath) {
        self.fileManager = fileManager
        self.bundlePath = bundlePath
    }

    private var plistURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public var isInstalled: Bool { fileManager.fileExists(atPath: plistURL.path) }

    /// Installa/aggiorna l'agent con l'intervallo dato (in secondi). Ricarica launchd.
    public func install(intervalSeconds: Int) {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-g", bundlePath, "--args", "--scheduled-scan"],
            "StartInterval": intervalSeconds,
            "RunAtLoad": false
        ]
        try? fileManager.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        (dict as NSDictionary).write(to: plistURL, atomically: true)
        reload(load: true)
    }

    /// Rimuove l'agent e lo scarica da launchd.
    public func remove() {
        reload(load: false)
        try? fileManager.removeItem(at: plistURL)
    }

    private func reload(load: Bool) {
        // Scarica sempre l'eventuale versione precedente, poi carica se richiesto.
        run(["bootout", "gui/\(getuid())", plistURL.path])
        if load {
            run(["bootstrap", "gui/\(getuid())", plistURL.path])
        }
    }

    private func run(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
