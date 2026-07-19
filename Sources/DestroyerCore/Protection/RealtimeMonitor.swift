import Foundation

/// Monitoraggio "leggero" in tempo reale (senza Endpoint Security): osserva alcune cartelle
/// sensibili (Download, LaunchAgents) e, quando compare un file nuovo, lo ispeziona subito con
/// il motore. NON blocca l'esecuzione — avvisa dopo la comparsa. Fattibile senza entitlement Apple.
public final class RealtimeMonitor: @unchecked Sendable {

    private let scanner: MalwareScanner
    private let dirs: [URL]
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fds: [Int32] = []
    private var known: [String: Set<String>] = [:]
    /// Coda SERIALE: serializza gli handler dei vari watcher → nessun data race su `known`.
    private let queue = DispatchQueue(label: "io.github.destroyer.realtime")

    /// Chiamata (su main) quando un file appena comparso risulta sospetto.
    public var onThreat: ((ThreatFinding) -> Void)?

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                scanner: MalwareScanner = MalwareScanner()) {
        self.scanner = scanner
        self.dirs = [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        ]
    }

    public var isRunning: Bool { !sources.isEmpty }

    public func start() {
        guard sources.isEmpty else { return }
        for dir in dirs {
            known[dir.path] = snapshot(dir)
            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: .write, queue: queue)
            src.setEventHandler { [weak self] in self?.handleChange(dir) }
            let capturedFd = fd
            src.setCancelHandler { close(capturedFd) }
            fds.append(fd)
            sources.append(src)
            src.resume()
        }
    }

    public func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        fds.removeAll()
        known.removeAll()
    }

    private func handleChange(_ dir: URL) {
        let now = snapshot(dir)
        let added = now.subtracting(known[dir.path] ?? [])
        known[dir.path] = now
        for path in added {
            if let finding = scanner.inspect(fileURL: URL(fileURLWithPath: path)) {
                DispatchQueue.main.async { [weak self] in self?.onThreat?(finding) }
            }
        }
    }

    private func snapshot(_ dir: URL) -> Set<String> {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return Set(entries.map(\.path))
    }
}
