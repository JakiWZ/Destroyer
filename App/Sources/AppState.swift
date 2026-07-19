import SwiftUI

/// Sezioni della sidebar. Per l'MVP sono attive Dashboard e Applicazioni.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case cleanup
    case space
    case performance
    case protection
    case privacy
    case monitor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:    return "Dashboard"
        case .applications: return "Applicazioni"
        case .cleanup:      return "Pulizia"
        case .space:        return "Spazio"
        case .performance:  return "Prestazioni"
        case .protection:   return "Protezione"
        case .privacy:      return "Privacy"
        case .monitor:      return "Monitor"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:    return "gauge.with.dots.needle.67percent"
        case .applications: return "trash"
        case .cleanup:      return "sparkles"
        case .space:        return "chart.pie.fill"
        case .performance:  return "bolt.horizontal.fill"
        case .protection:   return "shield.lefthalf.filled"
        case .privacy:      return "hand.raised.fill"
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
            NotificationService.notifyThreat(
                title: "Destroyer: elemento sospetto",
                body: finding.family ?? finding.itemURL.lastPathComponent
            )
        }
        if UserDefaults.standard.bool(forKey: Self.realtimeKey) {
            setRealtime(true)
        }
    }

    func setRealtime(_ on: Bool) {
        realtimeEnabled = on
        UserDefaults.standard.set(on, forKey: Self.realtimeKey)
        if on {
            NotificationService.requestAuthorization()
            realtimeMonitor.start()
        } else {
            realtimeMonitor.stop()
        }
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
        let urls = notExcluded(junkGroups.flatMap { $0.items }.filter(\.isSelected).map(\.url))
        guard !urls.isEmpty else { return }
        let reclaimable = junkSelectedBytes
        let trash = self.trash
        Task {
            let outcome = await Task.detached { trash.trashAll(urls) }.value
            await MainActor.run {
                self.recordHistory("Pulizia junk", moves: outcome.moves)
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
                self.recordHistory("Disinstallazione \(name)", moves: outcome.moves)
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

    // MARK: - Esclusioni (protezione dell'utente da rimozioni indesiderate)
    private static let exclusionsKey = "exclusions.paths"
    @Published var exclusions: [String] = UserDefaults.standard.stringArray(forKey: "exclusions.paths") ?? []

    func isExcluded(_ url: URL) -> Bool { exclusions.contains { url.path == $0 || url.path.hasPrefix($0 + "/") } }
    func addExclusion(_ path: String) {
        guard !exclusions.contains(path) else { return }
        exclusions.append(path); UserDefaults.standard.set(exclusions, forKey: Self.exclusionsKey)
    }
    func removeExclusion(_ path: String) {
        exclusions.removeAll { $0 == path }; UserDefaults.standard.set(exclusions, forKey: Self.exclusionsKey)
    }
    private func notExcluded(_ urls: [URL]) -> [URL] { urls.filter { !isExcluded($0) } }

    // MARK: - Cronologia rimozioni (con ripristino)
    struct HistoryEntry: Codable, Identifiable {
        var id = UUID()
        let date: Date
        let summary: String
        let moves: [[String]]   // [original, inTrash]
    }
    private static let historyKey = "removal.history"
    @Published var history: [HistoryEntry] = {
        guard let data = UserDefaults.standard.data(forKey: "removal.history"),
              let h = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return [] }
        return h
    }()

    private func recordHistory(_ summary: String, moves: [RemovalOutcome.Move]) {
        guard !moves.isEmpty else { return }
        let entry = HistoryEntry(date: Date(), summary: summary, moves: moves.map { [$0.original.path, $0.inTrash.path] })
        history.insert(entry, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: Self.historyKey) }
    }

    /// Ripristina dalla cronologia gli elementi di una voce (dal Cestino alla posizione originale).
    func restoreHistory(_ entry: HistoryEntry) {
        let moves = entry.moves.compactMap { pair -> RemovalOutcome.Move? in
            guard pair.count == 2 else { return nil }
            return RemovalOutcome.Move(original: URL(fileURLWithPath: pair[0]), inTrash: URL(fileURLWithPath: pair[1]))
        }
        let trash = self.trash
        Task {
            _ = await Task.detached { trash.undo(moves) }.value
            await MainActor.run {
                self.history.removeAll { $0.id == entry.id }
                if let data = try? JSONEncoder().encode(self.history) { UserDefaults.standard.set(data, forKey: Self.historyKey) }
                self.refreshStatus()
            }
        }
    }

    // MARK: - TCC (permessi privacy) + Rete + Foto simili
    private let tccViewer = TCCViewer()
    private let networkMonitor = NetworkMonitor()
    private let photoScanner = PhotoScanner()
    @Published var tccEntries: [TCCEntry] = []
    @Published var connections: [Connection] = []
    @Published var photoGroups: [SimilarPhotoGroup] = []
    @Published var isScanningPhotos = false

    func scanTCC() {
        let v = tccViewer
        Task { let e = await Task.detached { v.entries() }.value; await MainActor.run { self.tccEntries = e } }
    }
    func scanConnections() {
        let m = networkMonitor
        Task { let c = await Task.detached { m.connections() }.value; await MainActor.run { self.connections = c } }
    }
    func scanPhotos() {
        isScanningPhotos = true
        let s = photoScanner
        Task {
            let g = await Task.detached { s.scan() }.value
            await MainActor.run { self.photoGroups = g; self.isScanningPhotos = false }
        }
    }
    func togglePhoto(groupID: UUID, fileID: URL) {
        if let g = photoGroups.firstIndex(where: { $0.id == groupID }),
           let f = photoGroups[g].photos.firstIndex(where: { $0.id == fileID }) {
            photoGroups[g].photos[f].isSelected.toggle()
        }
    }
    func trashSelectedPhotos() {
        let urls = notExcluded(photoGroups.flatMap { $0.photos }.filter(\.isSelected).map(\.url))
        guard !urls.isEmpty else { return }
        let trash = self.trash
        Task {
            let outcome = await Task.detached { trash.trashAll(urls) }.value
            await MainActor.run { self.recordHistory("Foto simili", moves: outcome.moves); self.scanPhotos(); self.refreshStatus() }
        }
    }

    // MARK: - Report esportabile
    func exportReport(to url: URL) {
        let junk = junkGroups.reduce(0) { $0 + $1.totalBytes }
        let dupes = duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
        var s = "# Report Destroyer\n\n"
        s += "_Generato: \(Date().formatted())_\n\n"
        if let r = smartResult { s += "- **Salute:** \(r.healthScore)/100\n" }
        s += "- **Junk:** \(ByteSize.string(junk))\n- **Duplicati recuperabili:** \(ByteSize.string(dupes))\n"
        s += "- **Minacce:** \(findings.count)\n- **Elementi di avvio:** \(loginItems.count)\n"
        try? s.data(using: .utf8)?.write(to: url)
    }

    // MARK: - Spazio (Space Lens, file grandi/vecchi, duplicati, lingue)
    private let spaceLens = SpaceLensScanner()
    private let fileInsight = FileInsightScanner()
    private let languageScanner = LanguageScanner()
    @Published var spaceEntries: [SpaceEntry] = []
    @Published var largeOldFiles: [ScannedFile] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var languageFiles: [LanguageFile] = []
    /// Flag di scansione PER SEZIONE (on-demand, così non parte tutto insieme).
    @Published var isScanningLens = false
    @Published var isScanningFiles = false
    @Published var isScanningLangs = false
    @Published var didScanFiles = false
    @Published var didScanLangs = false
    /// Radice corrente di Space Lens (navigabile).
    @Published var spaceRoot: URL = FileManager.default.homeDirectoryForCurrentUser

    /// Space Lens: mappa del disco della radice corrente.
    func scanSpaceLens() {
        isScanningLens = true
        let lens = spaceLens, root = spaceRoot
        Task {
            let entries = await Task.detached { lens.breakdown(of: root) }.value
            await MainActor.run { self.spaceEntries = entries; self.isScanningLens = false }
        }
    }

    /// File grandi/vecchi + duplicati in un'UNICA enumerazione.
    func scanFilesInsight() {
        isScanningFiles = true
        let insight = fileInsight
        Task {
            let r = await Task.detached { insight.analyze() }.value
            await MainActor.run {
                self.largeOldFiles = r.large
                self.duplicateGroups = r.duplicates
                self.isScanningFiles = false
                self.didScanFiles = true
            }
        }
    }

    /// File di lingua inutilizzati nelle app.
    func scanLanguages() {
        isScanningLangs = true
        let langs = languageScanner
        Task {
            let files = await Task.detached { langs.scan() }.value
            await MainActor.run { self.languageFiles = files; self.isScanningLangs = false; self.didScanLangs = true }
        }
    }

    /// Naviga dentro una cartella nella mappa spazio.
    func drillInto(_ entry: SpaceEntry) {
        guard entry.isDirectory else { return }
        spaceRoot = entry.url
        rescanSpaceLens()
    }

    /// Risale alla cartella superiore.
    func spaceUp() {
        let parent = spaceRoot.deletingLastPathComponent()
        guard parent.path.count > 1 else { return }
        spaceRoot = parent
        rescanSpaceLens()
    }

    var canSpaceGoUp: Bool { spaceRoot.path != "/" && spaceRoot.pathComponents.count > 1 }

    private func rescanSpaceLens() {
        let lens = spaceLens, root = spaceRoot
        Task {
            let entries = await Task.detached { lens.breakdown(of: root) }.value
            await MainActor.run { self.spaceEntries = entries }
        }
    }

    func toggleLanguage(_ file: LanguageFile) {
        if let i = languageFiles.firstIndex(where: { $0.id == file.id }) { languageFiles[i].isSelected.toggle() }
    }

    func toggleLargeOld(_ file: ScannedFile) {
        if let i = largeOldFiles.firstIndex(where: { $0.id == file.id }) {
            largeOldFiles[i].isSelected.toggle()
        }
    }

    func toggleDuplicate(groupID: UUID, fileID: URL) {
        if let g = duplicateGroups.firstIndex(where: { $0.id == groupID }),
           let f = duplicateGroups[g].files.firstIndex(where: { $0.id == fileID }) {
            duplicateGroups[g].files[f].isSelected.toggle()
        }
    }

    /// Sposta nel Cestino i file selezionati (grandi/vecchi + duplicati + lingue).
    func trashSelectedFiles() {
        let largeURLs: [URL] = largeOldFiles.filter(\.isSelected).map(\.url)
        let dupURLs: [URL] = duplicateGroups.flatMap { $0.files }.filter(\.isSelected).map(\.url)
        let langURLs: [URL] = languageFiles.filter(\.isSelected).map(\.url)
        let urls = notExcluded(largeURLs + dupURLs + langURLs)
        guard !urls.isEmpty else { return }
        let trash = self.trash
        Task {
            let outcome = await Task.detached { trash.trashAll(urls) }.value
            await MainActor.run { self.recordHistory("Spazio", moves: outcome.moves); self.scanFilesInsight(); self.scanLanguages(); self.refreshStatus() }
        }
    }

    // MARK: - Prestazioni (elementi di avvio)
    private let loginScanner = LoginItemsScanner()
    @Published var loginItems: [LoginItem] = []

    func scanLoginItems() {
        let scanner = loginScanner
        Task {
            let items = await Task.detached { scanner.scan() }.value
            await MainActor.run { self.loginItems = items }
        }
    }

    /// Rimuove un elemento di avvio (unload + Cestino, admin se di sistema).
    func removeLoginItem(_ item: LoginItem) {
        let category: LeftoverCategory = item.plistURL.deletingLastPathComponent()
            .lastPathComponent == "LaunchDaemons" ? .launchDaemons : .launchAgents
        let leftover = LeftoverItem(url: item.plistURL, category: category, sizeBytes: 0,
                                    isSystemProtected: false, requiresAuthorization: item.isSystem)
        let trash = self.trash
        let adminTrash = self.adminTrash
        Task {
            let outcome = await Task.detached { () -> RemovalOutcome in
                item.isSystem ? adminTrash.trash([leftover]) : trash.trashItems([leftover])
            }.value
            await MainActor.run {
                if !outcome.trashed.isEmpty { self.loginItems.removeAll { $0.id == item.id } }
            }
        }
    }

    // MARK: - Svuota Cestino (permanente)
    private let trashEmptier = TrashEmptier()
    @Published var emptiedCount: Int?

    func emptyTrash() {
        let emptier = trashEmptier
        Task {
            let n = await Task.detached { emptier.empty() }.value
            await MainActor.run { self.emptiedCount = n; self.refreshStatus() }
        }
    }

    // MARK: - Smart Scan (aggregato + punteggio salute)
    struct SmartResult {
        let healthScore: Int          // 0–100
        let junkBytes: Int64
        let threatCount: Int
        let startupCount: Int
    }
    @Published var smartResult: SmartResult?
    @Published var isSmartScanning = false

    // Trend di salute (storico dei punteggi Smart Scan).
    struct ScorePoint: Codable, Identifiable { var id = UUID(); let date: Date; let score: Int; let junkBytes: Int64 }
    @Published var healthHistory: [ScorePoint] = {
        guard let data = UserDefaults.standard.data(forKey: "health.history"),
              let h = try? JSONDecoder().decode([ScorePoint].self, from: data) else { return [] }
        return h
    }()
    private func recordHealth(_ score: Int, junk: Int64) {
        healthHistory.append(ScorePoint(date: Date(), score: score, junkBytes: junk))
        if healthHistory.count > 60 { healthHistory = Array(healthHistory.suffix(60)) }
        if let data = try? JSONEncoder().encode(healthHistory) { UserDefaults.standard.set(data, forKey: "health.history") }
    }

    // Onboarding + accento.
    @Published var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding.done")
    @Published var accentPreset: Int = Theme.accentPreset
    func setAccent(_ i: Int) { Theme.accentPreset = i; accentPreset = i; objectWillChange.send() }
    func finishOnboarding() { UserDefaults.standard.set(true, forKey: "onboarding.done"); showOnboarding = false }

    func smartScan() {
        isSmartScanning = true
        smartResult = nil
        let junkS = junkScanner, malwareS = malwareScanner, loginS = loginScanner
        Task {
            let junk = await Task.detached { junkS.scan() }.value
            let threats = await Task.detached { malwareS.scan(mode: .quick) }.value
            let startups = await Task.detached { loginS.scan() }.value
            let junkBytes = junk.reduce(0) { $0 + $1.totalBytes }
            let highThreats = threats.filter { $0.severity >= .medium }.count
            // Punteggio: parte da 100, penalità per minacce e junk.
            var score = 100
            score -= highThreats * 15
            if junkBytes > 5 * 1024 * 1024 * 1024 { score -= 15 }
            else if junkBytes > 1 * 1024 * 1024 * 1024 { score -= 8 }
            score = max(0, min(100, score))
            await MainActor.run {
                self.smartResult = SmartResult(
                    healthScore: score, junkBytes: junkBytes,
                    threatCount: threats.count, startupCount: startups.count
                )
                self.junkGroups = junk
                self.findings = threats
                self.loginItems = startups
                self.isSmartScanning = false
                self.recordHealth(score, junk: junkBytes)
            }
        }
    }

    /// "Correggi tutto" dallo Smart Scan: pulisce il junk trovato e aggiorna lo stato.
    func fixAll() {
        cleanJunk()
    }

    // MARK: - Manutenzione
    @Published var maintenanceDone: [Maintenance.Task] = []
    @Published var maintenanceError: String?

    func runMaintenance(_ tasks: [Maintenance.Task]) {
        let maint = Maintenance()
        Task {
            do {
                try await Task.detached { try maint.run(tasks) }.value
                await MainActor.run { self.maintenanceDone = tasks; self.maintenanceError = nil; self.refreshStatus() }
            } catch Maintenance.RunError.authorizationDenied {
                await MainActor.run { self.maintenanceError = "Autorizzazione negata" }
            } catch {
                await MainActor.run { self.maintenanceError = "\(error)" }
            }
        }
    }

    // MARK: - Privacy
    private let privacyScanner = PrivacyScanner()
    @Published var privacyItems: [PrivacyItem] = []
    @Published var isScanningPrivacy = false

    func scanPrivacy() {
        isScanningPrivacy = true
        let scanner = privacyScanner
        Task {
            let items = await Task.detached { scanner.scan() }.value
            await MainActor.run { self.privacyItems = items; self.isScanningPrivacy = false }
        }
    }

    func togglePrivacy(_ item: PrivacyItem) {
        if let i = privacyItems.firstIndex(where: { $0.id == item.id }) { privacyItems[i].isSelected.toggle() }
    }

    var privacySelectedBytes: Int64 { privacyItems.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }

    func clearPrivacy() {
        let urls = notExcluded(privacyItems.filter(\.isSelected).map(\.url))
        guard !urls.isEmpty else { return }
        let trash = self.trash
        Task {
            let outcome = await Task.detached { trash.trashAll(urls) }.value
            await MainActor.run { self.recordHistory("Privacy", moves: outcome.moves); self.scanPrivacy(); self.refreshStatus() }
        }
    }

    // MARK: - App Updater
    private let appUpdater = AppUpdater()
    @Published var appUpdates: [AppUpdate] = []
    @Published var brewAvailable = true
    @Published var isCheckingApps = false

    @Published var upgradingApp: String?

    func checkAppUpdates() {
        isCheckingApps = true
        let updater = appUpdater
        Task {
            let result = await updater.checkAll()
            await MainActor.run {
                self.appUpdates = result.updates
                self.brewAvailable = result.brewAvailable
                self.isCheckingApps = false
            }
        }
    }

    /// Aggiorna in-app (Homebrew) o apre la pagina (App Store/Internet).
    func updateApp(_ update: AppUpdate) {
        if update.source == .homebrew, let token = update.token {
            upgradingApp = update.name
            let updater = appUpdater
            Task {
                let ok = await Task.detached { updater.upgradeHomebrew(token: token) }.value
                await MainActor.run {
                    self.upgradingApp = nil
                    if ok { self.appUpdates.removeAll { $0.id == update.id } }
                }
            }
        } else if let url = update.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Wi-Fi salvati
    private let wifiScanner = WiFiScanner()
    @Published var wifiNetworks: [WiFiNetwork] = []

    func scanWiFi() {
        let scanner = wifiScanner
        Task {
            let nets = await Task.detached { scanner.scan() }.value
            await MainActor.run { self.wifiNetworks = nets }
        }
    }

    func removeWiFi(_ net: WiFiNetwork) {
        let scanner = wifiScanner
        Task {
            let ok = await Task.detached { scanner.remove([net.ssid]) }.value
            await MainActor.run { if ok { self.wifiNetworks.removeAll { $0.id == net.id } } }
        }
    }

    // MARK: - Binari universali
    private let fatScanner = UniversalBinaryScanner()
    @Published var fatBinaries: [FatBinary] = []
    @Published var thinnedCount: Int?

    func scanFatBinaries() {
        let scanner = fatScanner
        Task {
            let bins = await Task.detached { scanner.scan() }.value
            await MainActor.run { self.fatBinaries = bins }
        }
    }

    func toggleFat(_ b: FatBinary) {
        if let i = fatBinaries.firstIndex(where: { $0.id == b.id }) { fatBinaries[i].isSelected.toggle() }
    }

    /// Assottiglia (IRREVERSIBILE) i binari selezionati.
    func thinSelectedFat() {
        let urls = fatBinaries.filter(\.isSelected).map(\.url)
        guard !urls.isEmpty else { return }
        let scanner = fatScanner
        Task {
            let n = await Task.detached { scanner.thin(urls) }.value
            await MainActor.run { self.thinnedCount = n; self.scanFatBinaries(); self.refreshStatus() }
        }
    }

    // MARK: - Metriche live (CPU/batteria) per Monitor e menu bar
    private let liveMetrics = LiveMetrics()
    @Published var cpuUsage: Double = 0
    @Published var battery: LiveMetrics.Battery?
    @Published var netDownRate: Double = 0

    func refreshLive() {
        let m = liveMetrics
        Task {
            let cpu = await Task.detached { m.cpuUsage() }.value
            let bat = await Task.detached { m.battery() }.value
            let net = await Task.detached { m.network() }.value
            await MainActor.run { self.cpuUsage = cpu; self.battery = bat; self.netDownRate = net.bytesPerSecDown }
        }
    }

    // MARK: - Scansioni programmate (in-app, mentre l'app è aperta)
    private static let scheduleKey = "smartscan.interval.minutes"
    @Published var scheduleMinutes: Int = 0   // 0 = disattivo
    private var scheduleTimer: Timer?

    func restoreSchedule() {
        scheduleMinutes = UserDefaults.standard.integer(forKey: Self.scheduleKey)
        applySchedule()
    }

    func setSchedule(minutes: Int) {
        scheduleMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: Self.scheduleKey)
        applySchedule()
    }

    private let backgroundScheduler = BackgroundScheduler()

    private func applySchedule() {
        scheduleTimer?.invalidate()
        // Timer in-app (mentre l'app è aperta).
        if scheduleMinutes > 0 {
            scheduleTimer = Timer.scheduledTimer(withTimeInterval: Double(scheduleMinutes) * 60, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.smartScan() }
            }
        }
        // LaunchAgent in background (anche ad app chiusa).
        let scheduler = backgroundScheduler
        let minutes = scheduleMinutes
        Task.detached {
            if minutes > 0 { scheduler.install(intervalSeconds: minutes * 60) }
            else { scheduler.remove() }
        }
    }

    /// Se l'app è stata avviata dallo scheduler, esegue subito uno Smart Scan.
    func handleLaunchArguments() {
        if CommandLine.arguments.contains("--scheduled-scan") {
            smartScan()
        }
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
