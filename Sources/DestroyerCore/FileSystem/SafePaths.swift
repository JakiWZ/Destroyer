import Foundation

/// Guardia di sicurezza: decide se un percorso può essere rimosso (spostato nel Cestino).
///
/// Regole (fail-closed):
/// 1. Il path deve essere **contenuto strettamente** dentro una delle "allowed root"
///    (mai uguale alla root stessa: non svuotiamo `~/Library/Caches`).
/// 2. Il path non deve trovarsi dentro nessuna "denied root" di sistema.
/// 3. Nessun componente `..` (traversal) è ammesso.
///
/// Il confronto avviene per **componenti di path standardizzati**, non per prefisso di
/// stringa, così `~/Library/Caches` non "matcha" `~/Library/Caches-evil`.
public struct SafePaths {

    private let homeURL: URL
    private let allowedRoots: [URL]
    private let deniedRoots: [URL]

    /// - Parameter home: home directory dell'utente. Iniettabile per i test.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeURL = home.standardizedFileURL

        let lib = homeURL.appendingPathComponent("Library", isDirectory: true)
        func h(_ c: String) -> URL { lib.appendingPathComponent(c, isDirectory: true) }

        self.allowedRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeURL.appendingPathComponent("Applications", isDirectory: true),
            h("Caches"),
            h("Preferences"),
            h("Application Support"),
            h("Containers"),
            h("Group Containers"),
            h("Logs"),
            h("LaunchAgents"),
            // Posizioni di sistema (root): richiedono autorizzazione admin per la rimozione,
            // ma sono aree legittime dei residui di un'app. La denylist qui sotto le protegge
            // comunque da /System, /Library/Apple, ecc.
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
            URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true),
            URL(fileURLWithPath: "/Library/PrivilegedHelperTools", isDirectory: true),
            URL(fileURLWithPath: "/Library/Application Support", isDirectory: true),
            URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
            URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
            URL(fileURLWithPath: "/Library/Preferences", isDirectory: true),
            h("Saved Application State"),
            h("Application Scripts"),
            h("HTTPStorages"),
            h("WebKit"),
            h("Cookies")
        ].map { $0.standardizedFileURL }

        self.deniedRoots = [
            "/System",
            "/bin",
            "/sbin",
            "/usr",           // /usr/local viene ri-ammesso sotto
            "/private/var",
            "/private/etc",
            "/Library/Apple",
            "/Applications/Utilities"
        ].map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
    }

    /// Eccezioni: percorsi che, pur dentro una denied root, restano consentiti.
    private static let deniedExceptions: [URL] = [
        URL(fileURLWithPath: "/usr/local", isDirectory: true).standardizedFileURL
    ]

    /// Vero se `url` può essere rimosso in sicurezza.
    public func isRemovable(_ url: URL) -> Bool {
        let target = url.standardizedFileURL
        let comps = target.pathComponents

        // Nessun traversal residuo dopo la standardizzazione.
        guard !comps.contains("..") else { return false }
        // Mai la radice del filesystem.
        guard comps.count > 1 else { return false }

        // 2. Dentro una denied root? (salvo eccezioni esplicite)
        for denied in Self.deniedRoots(from: deniedRoots) {
            if Self.isContained(comps, inOrEqualTo: denied) {
                let allowedByException = Self.deniedExceptions.contains {
                    Self.isContained(comps, inOrEqualTo: $0.pathComponents)
                }
                if !allowedByException { return false }
            }
        }

        // 1. Strettamente dentro una allowed root (più profondo della root stessa).
        for root in allowedRoots {
            if Self.isStrictlyContained(comps, in: root.pathComponents) {
                return true
            }
        }
        return false
    }

    private static func deniedRoots(from urls: [URL]) -> [[String]] {
        urls.map { $0.pathComponents }
    }

    /// `comps` è dentro `root` **o uguale** a `root`.
    private static func isContained(_ comps: [String], inOrEqualTo root: [String]) -> Bool {
        guard comps.count >= root.count else { return false }
        return Array(comps.prefix(root.count)) == root
    }

    /// `comps` è **strettamente** dentro `root` (almeno un componente più profondo).
    private static func isStrictlyContained(_ comps: [String], in root: [String]) -> Bool {
        guard comps.count > root.count else { return false }
        return Array(comps.prefix(root.count)) == root
    }
}
