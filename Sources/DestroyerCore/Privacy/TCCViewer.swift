import Foundation

/// Un permesso concesso a un'app (dal database TCC di macOS).
public struct TCCEntry: Identifiable, Hashable, Sendable {
    public var id: String { client + service }
    public let client: String       // bundle id dell'app
    public let service: String      // permesso leggibile (Fotocamera, Microfono, …)
    public let granted: Bool

    public init(client: String, service: String, granted: Bool) {
        self.client = client; self.service = service; self.granted = granted
    }
}

/// Legge (sola lettura) i permessi privacy concessi alle app dal database TCC dell'utente.
/// Richiede Full Disk Access per leggere `TCC.db`.
public struct TCCViewer {

    public init() {}

    private var dbPath: String {
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
    }

    private static let serviceNames: [String: String] = [
        "kTCCServiceCamera": "Fotocamera",
        "kTCCServiceMicrophone": "Microfono",
        "kTCCServiceScreenCapture": "Registrazione schermo",
        "kTCCServiceSystemPolicyAllFiles": "Accesso completo al disco",
        "kTCCServiceSystemPolicyDesktopFolder": "Cartella Scrivania",
        "kTCCServiceSystemPolicyDocumentsFolder": "Cartella Documenti",
        "kTCCServiceSystemPolicyDownloadsFolder": "Cartella Download",
        "kTCCServiceAccessibility": "Accessibilità",
        "kTCCServiceContactsFull": "Contatti",
        "kTCCServiceCalendar": "Calendario",
        "kTCCServicePhotos": "Foto",
        "kTCCServiceReminders": "Promemoria",
        "kTCCServiceListenEvent": "Monitoraggio input"
    ]

    public var isReadable: Bool { FileManager.default.isReadableFile(atPath: dbPath) }

    public func entries() -> [TCCEntry] {
        guard isReadable else { return [] }
        // auth_value: 0 negato, 2 concesso (schema moderno).
        let sql = "SELECT client, service, auth_value FROM access;"
        let out = runSQLite(db: dbPath, query: sql)
        var result: [TCCEntry] = []
        for line in out.split(separator: "\n") {
            let cols = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 3 else { continue }
            let service = Self.serviceNames[cols[1]] ?? cols[1].replacingOccurrences(of: "kTCCService", with: "")
            let granted = (Int(cols[2]) ?? 0) >= 2
            result.append(TCCEntry(client: cols[0], service: service, granted: granted))
        }
        return result.sorted { $0.client < $1.client }
    }

    private func runSQLite(db: String, query: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [db, query]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
