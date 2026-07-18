import Foundation

/// Osserva il Cestino: quando un'app (.app) vi finisce, avvisa così l'utente può
/// pulire i residui — comportamento tipico di AppCleaner.
public final class TrashWatcher: @unchecked Sendable {

    private let trashURL: URL
    private let discovery: AppDiscovery
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var known: Set<String> = []

    /// Callback invocata (su main) con l'app appena spostata nel Cestino.
    public var onAppTrashed: ((InstalledApp) -> Void)?

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                discovery: AppDiscovery = AppDiscovery()) {
        self.trashURL = home.appendingPathComponent(".Trash", isDirectory: true)
        self.discovery = discovery
        self.known = currentApps()
    }

    public func start() {
        guard source == nil else { return }
        fd = open(trashURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .global()
        )
        src.setEventHandler { [weak self] in self?.handleChange() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
        }
        source = src
        src.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    private func handleChange() {
        let now = currentApps()
        let added = now.subtracting(known)
        known = now
        for path in added {
            if let app = discovery.app(at: URL(fileURLWithPath: path)) {
                DispatchQueue.main.async { [weak self] in self?.onAppTrashed?(app) }
            }
        }
    }

    private func currentApps() -> Set<String> {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: trashURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }
        return Set(entries.filter { $0.pathExtension == "app" }.map(\.path))
    }
}
