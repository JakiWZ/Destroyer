import Foundation

/// Attività di manutenzione del sistema (stile CleanMyMac "Maintenance").
/// Richiedono privilegi di amministratore: una singola richiesta password copre la selezione.
public struct Maintenance {

    public enum Task: String, CaseIterable, Identifiable, Sendable {
        case flushDNS
        case freeRAM
        case reindexSpotlight

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .flushDNS:          return "Svuota cache DNS"
            case .freeRAM:           return "Libera memoria RAM"
            case .reindexSpotlight:  return "Reindicizza Spotlight"
            }
        }

        public var detail: String {
            switch self {
            case .flushDNS:          return "Risolve problemi di rete/navigazione"
            case .freeRAM:           return "Libera memoria inattiva"
            case .reindexSpotlight:  return "Ricostruisce l'indice di ricerca"
            }
        }

        /// Comando shell eseguito come root.
        var command: String {
            switch self {
            case .flushDNS:          return "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
            case .freeRAM:           return "/usr/sbin/purge"
            case .reindexSpotlight:  return "/usr/bin/mdutil -E / >/dev/null 2>&1 || true"
            }
        }
    }

    public enum RunError: Error, Equatable { case authorizationDenied, failed(String) }

    public init() {}

    /// Esegue le attività selezionate con un'unica autorizzazione admin.
    public func run(_ tasks: [Task]) throws {
        guard !tasks.isEmpty else { return }
        let command = tasks.map(\.command).joined(separator: "; ")
        let script = "do shell script \"\(escape(command))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return }

        let text = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if text.contains("-128") || text.localizedCaseInsensitiveContains("canceled") {
            throw RunError.authorizationDenied
        }
        throw RunError.failed(text.isEmpty ? "Errore sconosciuto" : text)
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
