import Foundation

/// Una connessione di rete attiva (processo → destinazione).
public struct Connection: Identifiable, Hashable, Sendable {
    public var id: String { process + pid + remote }
    public let process: String
    public let pid: String
    public let remote: String

    public init(process: String, pid: String, remote: String) {
        self.process = process; self.pid = pid; self.remote = remote
    }
}

/// Elenca (sola lettura) le connessioni di rete stabilite, aggregate per processo.
/// "Chi telefona a casa" — stile Little Snitch light, senza intercettare né bloccare.
public struct NetworkMonitor {

    public init() {}

    public func connections() -> [Connection] {
        // lsof: connessioni TCP stabilite, numeriche.
        let out = run(["/usr/sbin/lsof", "-nP", "-iTCP", "-sTCP:ESTABLISHED"])
        var result: [Connection] = []
        var seen = Set<String>()
        for line in out.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 9 else { continue }
            let name = cols[0], pid = cols[1]
            // La colonna NAME (es. "1.2.3.4:443->5.6.7.8:443") è l'ultima.
            let nameCol = cols.last ?? ""
            let remote = nameCol.components(separatedBy: "->").last ?? nameCol
            let conn = Connection(process: name, pid: pid, remote: remote)
            if seen.insert(conn.id).inserted { result.append(conn) }
        }
        return result.sorted { $0.process.localizedCaseInsensitiveCompare($1.process) == .orderedAscending }
    }

    private func run(_ argv: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
