import SwiftUI

/// Modulo Protezione: motore antimalware on-demand a 3 modalità.
/// Firme XProtect di Apple + euristica + persistenza. Rilevatore trasparente e difensivo.
struct ProtectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showESInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if appState.isScanningThreats {
                    scanning
                } else if !appState.didScanThreats {
                    intro
                    realtimeSection
                } else if appState.findings.isEmpty {
                    clean
                } else {
                    ForEach(appState.findings) { finding in
                        findingCard(finding)
                    }
                }
            }
            .padding(28)
        }
        .techGridBackground()
        .sheet(isPresented: $showSettings) { settingsSheet }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Protezione")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Scansione antimalware con le firme di Apple XProtect, euristica e analisi della persistenza.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: 560, alignment: .leading)
                Text("\(appState.signatureCount) firme XProtect caricate")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Impostazioni protezione")
        }
    }

    // MARK: - Sezione tempo reale (due quadratoni)

    private var realtimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protezione in tempo reale")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 14) {
                lightRealtimeCard
                endpointSecurityCard
            }
        }
    }

    private var lightRealtimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "eye.fill").foregroundStyle(Theme.accentSolid)
                Text("Monitoraggio leggero").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.realtimeEnabled },
                    set: { appState.setRealtime($0) }
                )).labelsHidden().toggleStyle(.switch)
            }
            Text("Sorveglia Download e LaunchAgents: quando compare un file nuovo lo analizza con XProtect e ti avvisa.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Text(appState.realtimeEnabled ? "● Attivo" : "○ Non attivo")
                .font(.caption2)
                .foregroundStyle(appState.realtimeEnabled ? Theme.ok : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .card(padding: 16, highlighted: appState.realtimeEnabled)
    }

    private var endpointSecurityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lock.shield.fill").foregroundStyle(Theme.textSecondary)
                Text("Endpoint Security").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("richiede setup").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.strokeStrong))
            }
            Text("Vero real-time che può BLOCCARE l'esecuzione. Richiede un entitlement Apple approvato + una System Extension.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Button("Perché non è attivo?") { showESInfo = true }
                .font(.caption2).foregroundStyle(Theme.accentSolid).buttonStyle(.plain)
                .popover(isPresented: $showESInfo) { esInfoPopover }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .card(padding: 16)
    }

    private var esInfoPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Endpoint Security (real-time completo)")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            Text("Per intercettare e bloccare i file prima dell'esecuzione, macOS richiede:")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Label("Entitlement Apple concesso su richiesta motivata", systemImage: "1.circle").font(.caption)
            Label("Una System Extension privilegiata separata", systemImage: "2.circle").font(.caption)
            Label("App notarizzata con identità riconosciuta", systemImage: "3.circle").font(.caption)
            Text("Finché non abbiamo l'entitlement, usa il monitoraggio leggero.")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
        }
        .padding(16).frame(width: 340)
    }

    // MARK: - Impostazioni (rotellina)

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Impostazioni Protezione")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)

            Toggle(isOn: Binding(get: { appState.realtimeEnabled }, set: { appState.setRealtime($0) })) {
                VStack(alignment: .leading) {
                    Text("Monitoraggio leggero in tempo reale").foregroundStyle(Theme.textPrimary)
                    Text("Osserva Download e LaunchAgents").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }

            Divider().overlay(Theme.stroke)

            VStack(alignment: .leading, spacing: 4) {
                Text("Scansione programmata").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Smart Scan automatico, anche ad app chiusa (LaunchAgent utente).").font(.caption).foregroundStyle(Theme.textSecondary)
                Picker("", selection: Binding(get: { appState.scheduleMinutes }, set: { appState.setSchedule(minutes: $0) })) {
                    Text("Off").tag(0)
                    Text("Ogni 30 min").tag(30)
                    Text("Ogni ora").tag(60)
                    Text("Ogni 6 ore").tag(360)
                }.pickerStyle(.segmented).labelsHidden()
            }

            Divider().overlay(Theme.stroke)

            VStack(alignment: .leading, spacing: 6) {
                Text("Disinstalla completamente").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Disattiva il monitoraggio e azzera tutte le impostazioni e i risultati della Protezione.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                AccentButton(title: "Disinstalla tutto", systemImage: "trash", role: .destructive) {
                    appState.resetProtection()
                    showSettings = false
                }
            }
            Spacer()
            HStack {
                Spacer()
                GhostButton(title: "Chiudi") { showSettings = false }
            }
        }
        .padding(24)
        .frame(width: 460, height: 460)
        .background(Theme.background)
    }

    private var intro: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 76, height: 76)
                    .shadow(color: Theme.accentMid.opacity(0.5), radius: 16)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
            }
            Text("Scegli la profondità di scansione")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 12) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    modeCard(mode)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private func modeCard(_ mode: ScanMode) -> some View {
        Button { appState.scanMalware(mode: mode) } label: {
            VStack(spacing: 8) {
                Image(systemName: icon(for: mode))
                    .font(.system(size: 24)).foregroundStyle(Theme.accentGradient)
                Text(mode.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(mode.subtitle)
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 150, height: 130)
            .card(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scansione \(mode.title): \(mode.subtitle)")
    }

    private func icon(for mode: ScanMode) -> String {
        switch mode {
        case .quick: return "bolt.fill"
        case .balanced: return "shield.fill"
        case .deep: return "magnifyingglass.circle.fill"
        }
    }

    private var scanning: some View {
        VStack(spacing: 14) {
            ProgressView(value: appState.scanProgress)
                .frame(maxWidth: 360)
            Text("Scansione \(appState.scanMode.title.lowercased()) in corso… \(Int(appState.scanProgress * 100))%")
                .foregroundStyle(Theme.textSecondary)
            GhostButton(title: "Annulla", systemImage: "xmark") { appState.cancelScan() }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    private var clean: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 46)).foregroundStyle(Theme.ok)
            Text("Nessuna minaccia rilevata")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text("Analisi con firme XProtect di Apple, euristica e persistenza.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            GhostButton(title: "Nuova scansione", systemImage: "arrow.clockwise") {
                appState.didScanThreats = false
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func findingCard(_ f: ThreatFinding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                severityBadge(f.severity)
                detectionBadge(f.detection)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(f.family ?? f.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if f.requiresAuthorization {
                            Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Theme.warning)
                        }
                    }
                    Text(f.itemURL.path).font(.system(size: 10)).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
                Spacer()
            }
            ForEach(Array(f.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9)).foregroundStyle(Theme.warning)
                    Text(reason).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                }
            }
            HStack {
                GhostButton(title: "Mostra nel Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([f.itemURL])
                }
                Spacer()
                AccentButton(title: "Metti in quarantena", systemImage: "trash", role: .destructive) {
                    appState.removeThreat(f)
                }
            }
        }
        .card(padding: 16, highlighted: f.severity == .high)
    }

    private func severityBadge(_ s: ThreatSeverity) -> some View {
        let color: Color = s == .high ? Theme.danger : (s == .medium ? Theme.warning : Theme.textTertiary)
        return Text(s.label.uppercased())
            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    private func detectionBadge(_ d: DetectionType) -> some View {
        Text(d.label)
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Theme.strokeStrong))
    }
}
