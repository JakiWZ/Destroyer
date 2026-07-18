import Foundation

/// Guardia di sicurezza: decide se un percorso può essere rimosso (spostato nel Cestino).
///
/// Modello (fail-closed):
/// 1. Il path deve essere **contenuto strettamente** dentro un'area consentita
///    (la HOME dell'utente, `/Applications`, o le directory di launch di `/Library`).
/// 2. NON deve essere l'esatta radice di una directory protetta (non svuotiamo `~/Downloads`,
///    `~/Library/Caches`, `/Applications`, ecc.: solo il loro contenuto).
/// 3. NON deve trovarsi in un'area di sistema critica (denylist).
/// 4. Nessun componente `..` (traversal).
///
/// Il confronto avviene per **componenti di path standardizzati**, non per prefisso di stringa.
public struct SafePaths {

    private let home: URL
    /// Contenitori dentro cui è lecito rimuovere (solo il contenuto, non la radice).
    private let allowedRoots: [[String]]
    /// Aree di sistema critiche: mai toccabili.
    private let deniedRoots: [[String]]
    /// Directory-radice protette: eliminabile il contenuto, non la cartella stessa.
    private let protectedExact: Set<String>

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let h = home.standardizedFileURL
        self.home = h
        let lib = h.appendingPathComponent("Library", isDirectory: true)

        func sys(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true).standardizedFileURL }

        // 1) Contenitori consentiti.
        let allowed: [URL] = [
            h,                                                   // tutta la home dell'utente
            sys("/Applications"),
            sys("/Library/LaunchAgents"),
            sys("/Library/LaunchDaemons"),
            sys("/Library/PrivilegedHelperTools"),
            sys("/Library/Application Support"),
            sys("/Library/Caches"),
            sys("/Library/Logs"),
            sys("/Library/Preferences")
        ]
        self.allowedRoots = allowed.map { $0.pathComponents }

        // 2) Sistema critico (denylist). /usr/local è ri-ammesso come eccezione.
        self.deniedRoots = [
            "/System", "/bin", "/sbin", "/usr", "/private/var", "/private/etc",
            "/Library/Apple", "/Applications/Utilities"
        ].map { sys($0).pathComponents } + [lib.appendingPathComponent("Keychains").pathComponents]

        // 3) Directory-radice protette (non eliminabili, solo il loro contenuto).
        var prot: Set<String> = [h.path, "/Applications",
            "/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/PrivilegedHelperTools",
            "/Library/Application Support", "/Library/Caches", "/Library/Logs", "/Library/Preferences"]
        for top in ["Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures",
                    "Public", "Sites", "Applications", "Library", ".Trash"] {
            prot.insert(h.appendingPathComponent(top).path)
        }
        for l in ["Caches", "Preferences", "Application Support", "Containers", "Group Containers",
                  "Logs", "LaunchAgents", "Saved Application State", "Application Scripts",
                  "HTTPStorages", "WebKit", "Cookies", "Developer", "Safari", "Mail",
                  "Mail Downloads", "Keychains"] {
            prot.insert(lib.appendingPathComponent(l).path)
        }
        self.protectedExact = prot
    }

    private static let usrLocal = URL(fileURLWithPath: "/usr/local", isDirectory: true).standardizedFileURL.pathComponents

    /// Vero se `url` può essere rimosso in sicurezza.
    public func isRemovable(_ url: URL) -> Bool {
        let target = url.standardizedFileURL
        let comps = target.pathComponents

        guard !comps.contains("..") else { return false }
        guard comps.count > 1 else { return false }

        // 3) Area di sistema critica (salvo eccezione /usr/local).
        for denied in deniedRoots where Self.contained(comps, in: denied) {
            if !Self.contained(comps, in: Self.usrLocal) { return false }
        }

        // 2) Radice protetta: non eliminabile la cartella stessa.
        if protectedExact.contains(target.path) { return false }

        // 1) Strettamente dentro un contenitore consentito.
        for root in allowedRoots where Self.strictlyContained(comps, in: root) {
            return true
        }
        return false
    }

    /// `comps` è dentro `root` (o uguale).
    private static func contained(_ comps: [String], in root: [String]) -> Bool {
        guard comps.count >= root.count else { return false }
        return Array(comps.prefix(root.count)) == root
    }

    /// `comps` è **strettamente** dentro `root` (almeno un livello più profondo).
    private static func strictlyContained(_ comps: [String], in root: [String]) -> Bool {
        guard comps.count > root.count else { return false }
        return Array(comps.prefix(root.count)) == root
    }
}
