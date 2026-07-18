import SwiftUI

/// Contenuto dell'app nella barra dei menu: stato rapido + azioni.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(Theme.accentSolid)
                Text("Destroyer").font(.system(size: 14, weight: .bold))
                Spacer()
                if appState.realtimeEnabled {
                    Label("live", systemImage: "shield.fill").font(.caption2).foregroundStyle(Theme.ok)
                }
            }

            if let s = appState.snapshot {
                stat("Disco libero", ByteSize.string(s.diskAvailableBytes), s.diskUsedFraction)
                stat("RAM usata", "\(Int(s.ramUsedFraction * 100))%", s.ramUsedFraction)
                stat("Cestino", ByteSize.string(s.trashBytes), nil)
            } else {
                Text("Lettura stato…").font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Button {
                appState.smartScan()
                NSApp.activate(ignoringOtherApps: true)
            } label: { Label("Smart Scan", systemImage: "sparkles") }

            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: { Label("Apri Destroyer", systemImage: "macwindow") }

            Divider()
            Button("Esci") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 260)
        .onAppear { appState.refreshStatus() }
    }

    private func stat(_ title: String, _ value: String, _ fraction: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.gray.opacity(0.25))
                        Capsule().fill(Theme.accentGradient).frame(width: max(3, geo.size.width * fraction))
                    }
                }.frame(height: 4)
            }
        }
    }
}
