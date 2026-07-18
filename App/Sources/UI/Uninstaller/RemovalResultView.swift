import SwiftUI

struct RemovalResultView: View {
    @EnvironmentObject var appState: AppState
    let summary: AppState.RemovalSummary

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            GaugeRing(value: 1, lineWidth: 16) {
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.accentGradient)
            }
            .frame(width: 150, height: 150)

            VStack(spacing: 6) {
                Text("\(summary.appName) rimossa")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(summary.trashedCount) elementi spostati nel Cestino")
                    .foregroundStyle(Theme.textSecondary)
                Text("\(ByteSize.string(summary.reclaimedBytes)) liberati")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ok)
                if summary.failedCount > 0 {
                    Text("\(summary.failedCount) non riusciti")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                }
            }

            if !summary.failures.isEmpty {
                failuresList
            }

            HStack(spacing: 12) {
                if summary.canUndo {
                    GhostButton(title: "Annulla rimozione", systemImage: "arrow.uturn.backward") {
                        appState.undoLastRemoval()
                    }
                }
                AccentButton(title: "Fatto", systemImage: "checkmark") { appState.reset() }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private var failuresList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Elementi non rimossi")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.warning)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(summary.failures.enumerated()), id: \.offset) { _, f in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.warning)
                            Text(f.url.lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textPrimary)
                            Text("— \(f.message)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(14)
        .frame(maxWidth: 420)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).strokeBorder(Theme.stroke))
    }
}
