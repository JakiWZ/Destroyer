import SwiftUI

/// Modulo Prestazioni: gestione degli elementi di avvio (login/background items).
struct PerformanceView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if appState.loginItems.isEmpty {
                    Text("Nessun elemento di avvio trovato.")
                        .font(.caption).foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    ForEach(appState.loginItems) { item in
                        itemRow(item)
                    }
                }
            }
            .padding(28)
        }
        .techGridBackground()
        .onAppear { if appState.loginItems.isEmpty { appState.scanLoginItems() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TechTag(text: "startup manager")
            Text("Prestazioni").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Elementi che partono automaticamente all'avvio. Rimuovili per alleggerire il Mac.")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func itemRow(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 20)).foregroundStyle(item.runAtLoad ? Theme.accentSolid : Theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if item.isSystem { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Theme.warning) }
                }
                Text(item.programPath ?? item.plistURL.path).font(Theme.mono(9)).foregroundStyle(Theme.textTertiary).lineLimit(1)
            }
            Spacer()
            if item.runAtLoad {
                Text("RUN AT LOAD").font(Theme.mono(8, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.strokeStrong))
            }
            GhostButton(title: "Rimuovi", systemImage: "trash") { appState.removeLoginItem(item) }
        }
        .card(padding: 14)
    }
}
