import SwiftUI

/// Cronologia delle rimozioni con ripristino dal Cestino.
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cronologia rimozioni").font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                GhostButton(title: "Chiudi") { dismiss() }
            }
            if appState.history.isEmpty {
                Text("Nessuna rimozione registrata.").font(.caption).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.history) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "trash").foregroundStyle(Theme.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.summary).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                                    Text("\(entry.moves.count) elementi · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(Theme.mono(9)).foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                GhostButton(title: "Ripristina", systemImage: "arrow.uturn.backward") { appState.restoreHistory(entry) }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
