import Foundation

/// Orchestrazione del flusso di disinstallazione: scan → review → remove.
/// Espone risultati aggregati alla UI senza che questa conosca i dettagli del filesystem.
public final class UninstallCoordinator: @unchecked Sendable {

    private let discovery: AppDiscovery
    private let finder: LeftoverFinder
    private let trash: TrashService
    private let adminTrash: AdminTrashService
    private let process: AppProcess
    private let fileManager: FileManager

    public init(
        discovery: AppDiscovery = AppDiscovery(),
        finder: LeftoverFinder = LeftoverFinder(),
        trash: TrashService = TrashService(),
        adminTrash: AdminTrashService = AdminTrashService(),
        process: AppProcess = AppProcess(),
        fileManager: FileManager = .default
    ) {
        self.discovery = discovery
        self.finder = finder
        self.trash = trash
        self.adminTrash = adminTrash
        self.process = process
        self.fileManager = fileManager
    }

    /// Risultato della scansione: l'app + tutti i residui trovati (bundle incluso come binary).
    public struct ScanResult {
        public let app: InstalledApp
        public var items: [LeftoverItem]

        public init(app: InstalledApp, items: [LeftoverItem]) {
            self.app = app
            self.items = items
        }

        /// Totale byte selezionati per la rimozione.
        public var selectedBytes: Int64 {
            items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
        }
    }

    /// Scansiona un bundle .app: legge i metadati e trova i residui.
    public func scan(bundleURL: URL) -> ScanResult? {
        guard let app = discovery.app(at: bundleURL) else { return nil }
        return scan(app: app)
    }

    /// Scansiona un'app già nota.
    public func scan(app: InstalledApp) -> ScanResult {
        var items: [LeftoverItem] = []
        // Il bundle stesso come primo item (categoria .binary). Se è di proprietà root
        // (installazione di sistema), la rimozione richiederà autorizzazione admin.
        let bundleParent = app.bundleURL.deletingLastPathComponent().path
        let bundleNeedsAuth = !fileManager.isWritableFile(atPath: bundleParent)
        items.append(LeftoverItem(
            url: app.bundleURL,
            category: .binary,
            sizeBytes: app.sizeBytes,
            isSystemProtected: false,
            requiresAuthorization: bundleNeedsAuth
        ))
        items.append(contentsOf: finder.findLeftovers(for: app))
        return ScanResult(app: app, items: items)
    }

    /// Vero se l'app risulta in esecuzione (va chiusa prima di disinstallarla).
    public func isAppRunning(_ app: InstalledApp) -> Bool {
        process.isRunning(bundleIdentifier: app.bundleIdentifier)
    }

    /// Chiude l'app se in esecuzione. Ritorna true se non è più attiva.
    @discardableResult
    public func quitApp(_ app: InstalledApp) -> Bool {
        process.quit(bundleIdentifier: app.bundleIdentifier)
    }

    /// Rimuove (Cestino) gli item selezionati, saltando quelli deselezionati.
    /// Gli item di sistema (`requiresAuthorization`) passano dalla rimozione admin,
    /// che mostra il pannello password di macOS.
    public func remove(_ items: [LeftoverItem], app: InstalledApp? = nil) -> RemovalOutcome {
        // Chiudi l'app prima di rimuoverne il bundle/residui.
        if let app { _ = quitApp(app) }

        let selected = items.filter(\.isSelected)
        let normalItems = selected.filter { !$0.requiresAuthorization }
        let privilegedItems = selected.filter { $0.requiresAuthorization }

        var outcome = trash.trashItems(normalItems)
        if !privilegedItems.isEmpty {
            outcome = outcome.merged(with: adminTrash.trash(privilegedItems))
        }
        return outcome
    }

    /// Vero se tra gli item selezionati ce n'è almeno uno che richiede autorizzazione admin.
    public func selectionNeedsAuthorization(_ items: [LeftoverItem]) -> Bool {
        items.contains { $0.isSelected && $0.requiresAuthorization }
    }
}
