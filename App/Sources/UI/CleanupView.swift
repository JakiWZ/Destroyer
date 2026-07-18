import SwiftUI

/// Modulo Pulizia: scansione sicura di cache/log utente, rimozione nel Cestino.
struct CleanupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if appState.isScanningJunk {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Scansione…").foregroundStyle(Theme.textSecondary) }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if appState.junkGroups.isEmpty {
                    emptyState
                } else {
                    ForEach(appState.junkGroups) { group in
                        groupCard(group)
                    }
                    footer
                }
            }
            .padding(28)
        }
        .onAppear { if appState.junkGroups.isEmpty { appState.scanJunk() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pulizia")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Cache e log ricreabili: vengono spostati nel Cestino (reversibile).")
                .foregroundStyle(Theme.textSecondary)
            if let cleaned = appState.junkCleanedBytes {
                Text("Puliti \(ByteSize.string(cleaned)) 🎉")
                    .font(.subheadline).foregroundStyle(Theme.ok)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(Theme.accentGradient)
            Text("Tutto pulito").font(.headline).foregroundStyle(Theme.textPrimary)
            GhostButton(title: "Ripeti scansione", systemImage: "arrow.clockwise") { appState.scanJunk() }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func groupCard(_ group: JunkGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(group.name, systemImage: group.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(ByteSize.string(group.totalBytes)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(group.items.prefix(12)) { item in
                    HStack(spacing: 10) {
                        Button { appState.toggleJunk(groupID: group.id, itemID: item.id) } label: {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isSelected ? Theme.accentSolid : Theme.textTertiary)
                        }.buttonStyle(.plain)
                        Text(item.url.lastPathComponent).font(.system(size: 12)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Spacer()
                        Text(ByteSize.string(item.sizeBytes)).font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    if item.id != group.items.prefix(12).last?.id { Divider().overlay(Theme.stroke) }
                }
            }
            .card(padding: 4)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(ByteSize.string(appState.junkSelectedBytes)) selezionati")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Spacer()
            AccentButton(title: "Pulisci nel Cestino", systemImage: "sparkles") { appState.cleanJunk() }
                .opacity(appState.junkSelectedBytes == 0 ? 0.5 : 1)
                .disabled(appState.junkSelectedBytes == 0)
        }
    }
}
