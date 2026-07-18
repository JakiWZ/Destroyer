import SwiftUI

/// Modulo Protezione: motore antimalware on-demand a 3 modalità.
/// Firme XProtect di Apple + euristica + persistenza. Rilevatore trasparente e difensivo.
struct ProtectionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if appState.isScanningThreats {
                    scanning
                } else if !appState.didScanThreats {
                    intro
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
    }

    private var header: some View {
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
