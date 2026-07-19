import SwiftUI

/// Modulo Prestazioni: gestione degli elementi di avvio (login/background items).
struct PerformanceView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                maintenanceCard
                TechTag(text: "startup items")
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

    @State private var selectedTasks: Set<Maintenance.Task> = Set(Maintenance.Task.allCases)

    private var maintenanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TechTag(text: "maintenance")
            ForEach(Maintenance.Task.allCases) { task in
                HStack(spacing: 10) {
                    Button {
                        if selectedTasks.contains(task) { selectedTasks.remove(task) } else { selectedTasks.insert(task) }
                    } label: {
                        Image(systemName: selectedTasks.contains(task) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedTasks.contains(task) ? Theme.accentSolid : Theme.textTertiary)
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                        Text(task.detail).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                }
            }
            HStack {
                if let err = appState.maintenanceError {
                    Label(err, systemImage: "exclamationmark.triangle").font(.caption2).foregroundStyle(Theme.warning)
                } else if !appState.maintenanceDone.isEmpty {
                    Label("Completato", systemImage: "checkmark.circle").font(.caption2).foregroundStyle(Theme.ok)
                }
                Spacer()
                AccentButton(title: "Esegui (admin)", systemImage: "wrench.and.screwdriver") {
                    appState.runMaintenance(Array(selectedTasks))
                }
                .opacity(selectedTasks.isEmpty ? 0.5 : 1).disabled(selectedTasks.isEmpty)
            }
        }
        .card(padding: 16)
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
            Text("IMPATTO \(item.impact.label.uppercased())")
                .font(Theme.mono(8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Capsule().fill(impactColor(item.impact)))
            GhostButton(title: "Rimuovi", systemImage: "trash") { appState.removeLoginItem(item) }
        }
        .card(padding: 14)
    }

    private func impactColor(_ i: LoginItem.Impact) -> Color {
        switch i {
        case .high: return Theme.danger
        case .medium: return Theme.warning
        case .low: return Theme.textTertiary
        }
    }
}
