import SwiftUI

/// Monitor in tempo reale: aggiorna disco/RAM/Cestino ogni 2 secondi.
struct MonitorView: View {
    @EnvironmentObject var appState: AppState
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monitor")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Aggiornamento in tempo reale ogni 2 secondi")
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 20) {
                    gauge(title: "CPU", value: appState.cpuUsage)
                    gauge(title: "Memoria", value: appState.snapshot?.ramUsedFraction ?? 0)
                    gauge(title: "Disco", value: appState.snapshot?.diskUsedFraction ?? 0)
                }

                if let s = appState.snapshot {
                    HStack(spacing: 16) {
                        StatTile(icon: "cpu", title: "CPU",
                                 value: "\(Int(appState.cpuUsage * 100))%", fraction: appState.cpuUsage)
                        StatTile(icon: "internaldrive", title: "DISCO LIBERO",
                                 value: ByteSize.string(s.diskAvailableBytes), fraction: s.diskUsedFraction)
                        StatTile(icon: "memorychip", title: "RAM USATA",
                                 value: ByteSize.string(s.ramUsedBytes), fraction: s.ramUsedFraction)
                        StatTile(icon: "network", title: "RETE",
                                 value: "\(ByteSize.string(Int64(appState.netDownRate)))/s")
                        if let b = appState.battery, b.isPresent {
                            StatTile(icon: b.isCharging ? "battery.100.bolt" : "battery.75",
                                     title: "BATTERIA", value: "\(Int(b.level * 100))%",
                                     caption: b.isCharging ? "in carica" : nil, fraction: b.level)
                        } else {
                            StatTile(icon: "trash", title: "CESTINO", value: ByteSize.string(s.trashBytes))
                        }
                    }
                }
            }
            .padding(28)
        }
        .techGridBackground()
        .onAppear { appState.refreshStatus(); appState.refreshLive() }
        .onReceive(tick) { _ in appState.refreshStatus(); appState.refreshLive() }
    }

    private func gauge(title: String, value: Double) -> some View {
        VStack(spacing: 10) {
            GaugeRing(value: value, lineWidth: 14) {
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 130, height: 130)
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }
}
