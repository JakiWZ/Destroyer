import SwiftUI

/// Modulo Protezione: rileva persistenza sospetta (LaunchAgents/Daemons).
/// Rilevatore difensivo trasparente, non un antivirus a firme.
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Protezione")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Controlla i punti di avvio automatico (LaunchAgents/Daemons) alla ricerca di persistenza sospetta.")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            Spacer()
            if appState.didScanThreats && !appState.isScanningThreats {
                GhostButton(title: "Riscansiona", systemImage: "arrow.clockwise") { appState.scanThreats() }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 76, height: 76)
                    .shadow(color: Theme.accentMid.opacity(0.5), radius: 16)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
            }
            Text("Avvia un controllo di sicurezza")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            AccentButton(title: "Scansiona ora", systemImage: "magnifyingglass") { appState.scanThreats() }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private var scanning: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Analisi dei punti di persistenza…").foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    private var clean: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 46)).foregroundStyle(Theme.ok)
            Text("Nessuna persistenza sospetta")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text("I launch item analizzati risultano firmati e in posizioni attese.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func findingCard(_ f: ThreatFinding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                severityBadge(f.severity)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(f.title)
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
                AccentButton(title: "Rimuovi", systemImage: "trash", role: .destructive) {
                    appState.removeThreat(f)
                }
            }
        }
        .card(padding: 16, highlighted: f.severity == .high)
    }

    private func severityBadge(_ s: ThreatSeverity) -> some View {
        let color: Color = s == .high ? Theme.danger : (s == .medium ? Theme.warning : Theme.textTertiary)
        return Text(s.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(color))
    }
}
