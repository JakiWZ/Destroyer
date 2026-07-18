import Foundation

/// Scarica (unload) i LaunchAgent/Daemon prima di rimuoverne il .plist,
/// così il servizio smette subito di girare invece di restare attivo fino al riavvio.
public enum LaunchctlService {

    /// Categorie che rappresentano un job launchd.
    public static func isLaunchJob(_ category: LeftoverCategory) -> Bool {
        category == .launchAgents || category == .launchDaemons
    }

    /// Scarica un LaunchAgent utente (nessun privilegio richiesto). Best-effort.
    public static func unloadUserAgent(_ plistURL: URL) {
        let uid = getuid()
        // `bootout gui/<uid> <plist>` è la forma moderna; fallback a `unload`.
        run(["bootout", "gui/\(uid)", plistURL.path])
        run(["unload", "-w", plistURL.path])
    }

    /// Snippet shell (da eseguire come root) per scaricare un job di sistema.
    /// Usato dentro il comando admin unico di `AdminTrashService`.
    public static func systemUnloadCommand(for plistURL: URL, category: LeftoverCategory) -> String? {
        guard isLaunchJob(category) else { return nil }
        let quoted = "'" + plistURL.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        // `|| true`: non far fallire l'intera operazione se il job non era caricato.
        return "/bin/launchctl bootout system \(quoted) 2>/dev/null || true"
    }

    private static func run(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
