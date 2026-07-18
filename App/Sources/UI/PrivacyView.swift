import SwiftUI

/// Modulo Privacy: dati di navigazione dei browser (cache, cookie, cronologia).
struct PrivacyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if appState.isScanningPrivacy {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Analisi…").foregroundStyle(Theme.textSecondary) }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if appState.privacyItems.isEmpty {
                    empty
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.privacyItems) { item in row(item) }
                    }.card(padding: 4)
                    footer
                }
            }
            .padding(28)
        }
        .techGridBackground()
        .onAppear { if appState.privacyItems.isEmpty { appState.scanPrivacy() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TechTag(text: "privacy cleaner")
            Text("Privacy").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Cache, cookie e cronologia dei browser. Vengono spostati nel Cestino (reversibile).")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.fill").font(.system(size: 40)).foregroundStyle(Theme.accentGradient)
            Text("Nessun dato di navigazione trovato").font(.headline).foregroundStyle(Theme.textPrimary)
            GhostButton(title: "Ripeti scansione", systemImage: "arrow.clockwise") { appState.scanPrivacy() }
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func row(_ item: PrivacyItem) -> some View {
        HStack(spacing: 10) {
            Button { appState.togglePrivacy(item) } label: {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isSelected ? Theme.accentSolid : Theme.textTertiary)
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.browser) · \(item.kind)").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text(item.url.path).font(Theme.mono(9)).foregroundStyle(Theme.textTertiary).lineLimit(1)
            }
            Spacer()
            Text(ByteSize.string(item.sizeBytes)).font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Text("\(ByteSize.string(appState.privacySelectedBytes)) selezionati")
                .font(Theme.mono(12, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Spacer()
            AccentButton(title: "Pulisci nel Cestino", systemImage: "trash") { appState.clearPrivacy() }
                .opacity(appState.privacySelectedBytes == 0 ? 0.5 : 1)
                .disabled(appState.privacySelectedBytes == 0)
        }
    }
}
