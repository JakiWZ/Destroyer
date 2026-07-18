import Foundation

/// Verifica lo stato Gatekeeper/notarizzazione e l'attributo di quarantena di un file.
/// Un eseguibile non notarizzato + in quarantena in una posizione anomala è un forte indicatore.
public struct GatekeeperInspector {

    public enum Assessment: Sendable {
        case accepted      // Gatekeeper lo accetterebbe (notarizzato / dev noto)
        case rejected      // rifiutato (non notarizzato / firma non valida)
        case unknown
    }

    public init() {}

    /// `spctl --assess` valuta come farebbe Gatekeeper all'esecuzione.
    public func assess(path: String) -> Assessment {
        guard FileManager.default.fileExists(atPath: path) else { return .unknown }
        let status = run(["/usr/sbin/spctl", "--assess", "--type", "execute", path])
        switch status {
        case 0:  return .accepted
        case 3:  return .rejected   // codice tipico "rejected"
        default: return .rejected
        }
    }

    /// Vero se il file ha l'attributo esteso `com.apple.quarantine`
    /// (scaricato da internet e non ancora "approvato").
    public func isQuarantined(path: String) -> Bool {
        run(["/usr/bin/xattr", "-p", "com.apple.quarantine", path]) == 0
    }

    private func run(_ argv: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
