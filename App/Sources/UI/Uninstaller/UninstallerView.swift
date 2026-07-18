import SwiftUI
import UniformTypeIdentifiers

struct UninstallerView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTargeted = false
    @State private var search = ""

    var body: some View {
        Group {
            if let summary = appState.lastOutcome {
                RemovalResultView(summary: summary)
            } else if let scan = appState.scan {
                LeftoverReviewView(scan: scan)
            } else {
                chooser
            }
        }
        .onAppear { appState.loadInstalledApps() }
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disinstalla completamente")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Trascina un'app o scegline una: Destroyer rimuove anche i file residui.")
                        .foregroundStyle(Theme.textSecondary)
                }
                dropZone
                appListHeader
                appGrid
            }
            .padding(28)
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(isTargeted ? Theme.accentSolid.opacity(0.1) : Theme.surface)
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.stroke),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [9])
                )
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.accentGradient)
                Text("Trascina qui un'app")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("oppure scegline una dall'elenco")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if appState.isScanning {
                ProgressView("Scansione…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(height: 150)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { handleDrop($0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Area di trascinamento: rilascia qui un'app per disinstallarla")
    }

    private var appListHeader: some View {
        HStack {
            Text("App installate")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                TextField("Cerca", text: $search)
                    .textFieldStyle(.plain)
                    .frame(width: 160)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke))
        }
    }

    private var appGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 240), spacing: 14)]
        return LazyVGrid(columns: cols, spacing: 14) {
            ForEach(filteredApps) { app in
                AppCard(app: app) { appState.scan(app: app) }
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        guard !search.isEmpty else { return appState.installedApps }
        return appState.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension == "app" else { return }
            Task { @MainActor in appState.scanApp(at: url) }
        }
        return true
    }
}

struct AppCard: View {
    let app: InstalledApp
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(ByteSize.string(app.sizeBytes))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "trash")
                    .foregroundStyle(hovering ? Theme.accentSolid : Theme.textTertiary)
            }
            .card(padding: 14, highlighted: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disinstalla \(app.name), \(ByteSize.string(app.sizeBytes))")
        .accessibilityAddTraits(.isButton)
    }
}
