import SwiftUI

struct LeftoverReviewView: View {
    @EnvironmentObject var appState: AppState
    let scan: UninstallCoordinator.ScanResult
    @State private var confirming = false

    private var grouped: [(category: LeftoverCategory, items: [LeftoverItem])] {
        LeftoverCategory.allCases.compactMap { cat in
            let items = scan.items.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    private var selectedItems: [LeftoverItem] { scan.items.filter(\.isSelected) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if appState.scanAppRunning {
                runningBanner
            }
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(grouped, id: \.category) { group in
                        categorySection(group.category, items: group.items)
                    }
                }
                .padding(24)
            }
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: scan.app.bundleURL.path))
                .resizable().frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.app.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(scan.app.bundleIdentifier ?? scan.app.bundleURL.path)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            GhostButton(title: "Annulla", systemImage: "chevron.left") { appState.reset() }
        }
        .padding(24)
        .background(Theme.backgroundDeep)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    private var runningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Theme.warning)
            Text("\(scan.app.name) è in esecuzione: verrà chiusa automaticamente prima della rimozione.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(Theme.warning.opacity(0.12))
    }

    private func categorySection(_ category: LeftoverCategory, items: [LeftoverItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentSolid)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            VStack(spacing: 0) {
                ForEach(items) { item in
                    row(item)
                    if item.id != items.last?.id {
                        Divider().overlay(Theme.stroke)
                    }
                }
            }
            .card(padding: 4)
        }
    }

    private func row(_ item: LeftoverItem) -> some View {
        HStack(spacing: 10) {
            Button {
                appState.toggle(item)
            } label: {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isSelected ? Theme.accentSolid : Theme.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if item.requiresAuthorization {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.warning)
                            .help("File di sistema: richiede la password admin")
                    }
                }
                Text(item.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(ByteSize.string(item.sizeBytes))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private var needsAuth: Bool { selectedItems.contains(where: \.requiresAuthorization) }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedItems.count) elementi selezionati")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text("\(ByteSize.string(scan.selectedBytes)) recuperabili")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if needsAuth {
                        Label("richiede password admin", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.warning)
                    }
                }
            }
            Spacer()
            if appState.isRemoving {
                ProgressView().controlSize(.small)
                Text("Rimozione…").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            AccentButton(title: "Sposta nel Cestino", systemImage: "trash", role: .destructive) {
                confirming = true
            }
            .opacity(selectedItems.isEmpty || appState.isRemoving ? 0.5 : 1)
            .disabled(selectedItems.isEmpty || appState.isRemoving)
        }
        .padding(24)
        .background(Theme.backgroundDeep)
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
        .confirmationDialog(
            "Spostare \(selectedItems.count) elementi nel Cestino?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Sposta nel Cestino", role: .destructive) { appState.removeSelected() }
            Button("Annulla", role: .cancel) {}
        } message: {
            if needsAuth {
                Text("Alcuni elementi sono file di sistema: macOS ti chiederà la password admin. Potrai comunque ripristinarli dal Cestino.")
            } else {
                Text("Potrai ripristinarli dal Cestino in qualsiasi momento.")
            }
        }
    }
}
