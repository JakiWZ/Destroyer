import SwiftUI

/// Sezioni della sidebar. Per l'MVP sono attive Dashboard e Applicazioni.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case cleanup
    case protection
    case monitor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:    return "Dashboard"
        case .applications: return "Applicazioni"
        case .cleanup:      return "Pulizia"
        case .protection:   return "Protezione"
        case .monitor:      return "Monitor"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:    return "gauge.with.dots.needle.67percent"
        case .applications: return "trash"
        case .cleanup:      return "sparkles"
        case .protection:   return "shield.lefthalf.filled"
        case .monitor:      return "waveform.path.ecg"
        }
    }

    /// Tutti i moduli sono attivi.
    var isAvailable: Bool { true }
}

/// Stato radice dell'app: sezione selezionata, stato sistema e scansione corrente.
@MainActor
final class AppState: ObservableObject {
    @Published var section: AppSection = .dashboard
    @Published var scan: UninstallCoordinator.ScanResult?
    @Published var isScanning = false
    @Published var lastOutcome: RemovalSummary?
    @Published var installedApps: [InstalledApp] = []
    @Published var snapshot: SystemSnapshot?
    @Published var hasFullDiskAccess: Bool = true
    /// True se l'app in fase di review risulta in esecuzione (va chiusa prima).
    @Published var scanAppRunning = false

    private let coordinator = UninstallCoordinator()
    private let discovery = AppDiscovery()
    private let status = SystemStatus()
    private let junkScanner = JunkScanner()
    private let trash = TrashService()
    private let adminTrash = AdminTrashService()
    private let malwareScanner = MalwareScanner()

    // MARK: - Protezione
    @Published var findings: [ThreatFinding] = []
    @Published var isScanningThreats = false
    @Published var didScanThreats = false
    @Published var scanProgress: Double = 0
    @Published var scanMode: ScanMode = .quick
    private var cancelToken = CancelToken()

    /// Token di cancellazione thread-safe condiviso col motore off-main.
    final class CancelToken: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    }

    /// Numero di firme XProtect caricate (per mostrarlo nella UI).
    var signatureCount: Int { malwareScanner.signatureCount }

    func scanMalware(mode: ScanMode) {
        scanMode = mode
        isScanningThreats = true
        didScanThreats = false
        scanProgress = 0
        let token = CancelToken()
        cancelToken = token
        let scanner = malwareScanner
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                scanner.scan(
                    mode: mode,
                    progress: { p in Task { @MainActor [weak self] in self?.scanProgress = p } },
                    isCancelled: { token.isCancelled }
                )
            }.value
            await MainActor.run {
                self.findings = results
                self.isScanningThreats = false
                self.didScanThreats = true
            }
        }
    }

    func cancelScan() { cancelToken.cancel() }

    // MARK: - Protezione in tempo reale
    private let realtimeMonitor = RealtimeMonitor()
    private static let realtimeKey = "protection.realtime.enabled"
    @Published var realtimeEnabled = false
    /// Ultima minaccia rilevata dal monitor in tempo reale (per il banner).
    @Published var realtimeAlert: ThreatFinding?

    /// Ripristina lo stato del monitor dalle preferenze (all'avvio).
    func restoreRealtime() {
        realtimeMonitor.onThreat = { [weak self] finding in
            self?.realtimeAlert = finding
        }
        if UserDefaults.standard.bool(forKey: Self.realtimeKey) {
            setRealtime(true)
        }
    }

    func setRealtime(_ on: Bool) {
        realtimeEnabled = on
        UserDefaults.standard.set(on, forKey: Self.realtimeKey)
        if on { realtimeMonitor.start() } else { realtimeMonitor.stop() }
    }

    func dismissRealtimeAlert() { realtimeAlert = nil }

    /// Rotellina → "Disinstalla completamente": disattiva e azzera tutto ciò che è opzionale.
    func resetProtection() {
        setRealtime(false)
        findings = []
        didScanThreats = false
        realtimeAlert = nil
        UserDefaults.standard.removeObject(forKey: Self.realtimeKey)
    }

    /// Rimuove (Cestino) il launch item segnalato, scaricandolo prima con launchctl.
    func removeThreat(_ finding: ThreatFinding) {
        let category: LeftoverCategory = finding.itemURL.deletingLastPathComponent()
            .lastPathComponent == "LaunchDaemons" ? .launchDaemons : .launchAgents
        let item = LeftoverItem(
            url: finding.itemURL,
            category: category,
            sizeBytes: 0,
            isSystemProtected: false,
            requiresAuthorization: finding.requiresAuthorization
        )
        let trash = self.trash
        let adminTrash = self.adminTrash
        Task {
            let outcome = await Task.detached { () -> RemovalOutcome in
                if finding.requiresAuthorization {
                    return adminTrash.trash([item])
                } else {
                    return trash.trashItems([item])
                }
            }.value
            await MainActor.run {
                if !outcome.trashed.isEmpty {
                    self.findings.removeAll { $0.id == finding.id }
                }
            }
        }
    }

    // MARK: - Pulizia junk
    @Published var junkGroups: [JunkGroup] = []
    @Published var isScanningJunk = false
    @Published var junkCleanedBytes: Int64?

    func scanJunk() {
        isScanningJunk = true
        junkCleanedBytes = nil
        let scanner = junkScanner
        Task {
            let groups = await Task.detached { scanner.scan() }.value
            await MainActor.run {
                self.junkGroups = groups
                self.isScanningJunk = false
            }
        }
    }

    func toggleJunk(groupID: UUID, itemID: UUID) {
        guard let gi = junkGroups.firstIndex(where: { $0.id == groupID }),
              let ii = junkGroups[gi].items.firstIndex(where: { $0.id == itemID }) else { return }
        junkGroups[gi].items[ii].isSelected.toggle()
    }

    var junkSelectedBytes: Int64 { junkGroups.reduce(0) { $0 + $1.selectedBytes } }

    func cleanJunk() {
        let urls = junkGroups.flatMap { $0.items }.filter(\.isSelected).map(\.url)
        guard !urls.isEmpty else { return }
        let reclaimable = junkSelectedBytes
        let trash = self.trash
        Task {
            let outcome = await Task.detached { trash.trashAll(urls) }.value
            await MainActor.run {
                self.junkCleanedBytes = outcome.trashed.isEmpty ? 0 : reclaimable
                self.scanJunk()
                self.refreshStatus()
            }
        }
    }

    /// Esito arricchito con lo spazio liberato, per la schermata di risultato.
    struct RemovalSummary {
        let appName: String
        let trashedCount: Int
        let failedCount: Int
        let reclaimedBytes: Int64
        let failures: [RemovalOutcome.Failure]
        let moves: [RemovalOutcome.Move]
        var canUndo: Bool { !moves.isEmpty }
    }

    /// Numero di elementi ripristinati dall'ultimo Undo (per messaggio UI).
    @Published var undoneCount: Int?

    /// Ricontrolla il permesso Full Disk Access (chiamato in polling dal gate).
    func recheckAccess() {
        let granted = FullDiskAccess.isGranted()
        guard granted != hasFullDiskAccess else { return }
        hasFullDiskAccess = granted
        // Appena concesso, ricarica ciò che prima era bloccato.
        if granted {
            refreshStatus()
            loadInstalledApps()
        }
    }

    /// Apre il pannello Full Disk Access nelle Impostazioni di Sistema.
    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(FullDiskAccess.settingsURL)
    }

    // MARK: - Watcher Cestino
    private let trashWatcher = TrashWatcher()
    /// App appena spostata nel Cestino: suggerimento per pulire i residui.
    @Published var trashedAppSuggestion: InstalledApp?

    func startTrashWatcher() {
        trashWatcher.onAppTrashed = { [weak self] app in
            self?.trashedAppSuggestion = app
        }
        trashWatcher.start()
    }

    /// Avvia la pulizia dei residui dell'app appena cestinata.
    func cleanupTrashedApp() {
        guard let app = trashedAppSuggestion else { return }
        trashedAppSuggestion = nil
        section = .applications
        scan(app: app)
    }

    func dismissTrashedSuggestion() { trashedAppSuggestion = nil }

    func refreshStatus() {
        Task {
            let snap = status.snapshot()
            await MainActor.run { self.snapshot = snap }
        }
    }

    func loadInstalledApps() {
        Task {
            let apps = discovery.installedApps()
            await MainActor.run { self.installedApps = apps }
        }
    }

    func scanApp(at bundleURL: URL) {
        isScanning = true
        lastOutcome = nil
        Task {
            let result = coordinator.scan(bundleURL: bundleURL)
            let running = result.map { coordinator.isAppRunning($0.app) } ?? false
            await MainActor.run {
                self.scan = result
                self.scanAppRunning = running
                self.isScanning = false
            }
        }
    }

    func scan(app: InstalledApp) { scanApp(at: app.bundleURL) }

    func toggle(_ item: LeftoverItem) {
        guard var current = scan,
              let idx = current.items.firstIndex(where: { $0.id == item.id }) else { return }
        current.items[idx].isSelected.toggle()
        scan = current
    }

    /// True mentre è in corso una rimozione (può includere il prompt password admin).
    @Published var isRemoving = false

    func removeSelected() {
        guard let current = scan else { return }
        let reclaimable = current.selectedBytes
        let name = current.app.name
        let items = current.items
        let coordinator = self.coordinator
        isRemoving = true
        Task {
            // Fuori dal main thread: la rimozione admin può mostrare il pannello password.
            let app = current.app
            let outcome = await Task.detached(priority: .userInitiated) {
                coordinator.remove(items, app: app)
            }.value
            await MainActor.run {
                self.lastOutcome = RemovalSummary(
                    appName: name,
                    trashedCount: outcome.totalTrashed,
                    failedCount: outcome.failed.count,
                    reclaimedBytes: reclaimable,
                    failures: outcome.failed,
                    moves: outcome.moves
                )
                self.scan = nil
                self.isRemoving = false
                self.refreshStatus()
                self.loadInstalledApps()
            }
        }
    }

    /// Annulla l'ultima rimozione riportando i file dal Cestino alla posizione originale.
    func undoLastRemoval() {
        guard let summary = lastOutcome, summary.canUndo else { return }
        let moves = summary.moves
        let trash = self.trash
        Task {
            let restored = await Task.detached { trash.undo(moves) }.value
            await MainActor.run {
                self.undoneCount = restored
                self.lastOutcome = nil
                self.refreshStatus()
                self.loadInstalledApps()
            }
        }
    }

    func reset() {
        scan = nil
        lastOutcome = nil
        undoneCount = nil
    }

    // MARK: - Aggiornamenti
    @Published var updateResult: UpdateChecker.Result?
    @Published var isCheckingUpdate = false
    /// Imposta qui il tuo repo GitHub "owner/repo" per abilitare il controllo aggiornamenti.
    static let githubRepo = ""
    static let appVersion = "0.1.0"

    func checkForUpdates() {
        let checker = UpdateChecker(repo: Self.githubRepo, currentVersion: Self.appVersion)
        guard checker.isConfigured else { return }
        isCheckingUpdate = true
        Task {
            let result = try? await checker.check()
            await MainActor.run {
                self.updateResult = result
                self.isCheckingUpdate = false
            }
        }
    }
}
