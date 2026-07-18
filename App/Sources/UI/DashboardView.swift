import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heroCard
                statRow
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Buongiorno 👋")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            Text("Stato del tuo Mac")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private var heroCard: some View {
        HStack(spacing: 28) {
            GaugeRing(value: appState.snapshot?.diskUsedFraction ?? 0, lineWidth: 18) {
                VStack(spacing: 2) {
                    Text(diskPercent)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("disco usato")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 10) {
                Text("Spazio di archiviazione")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if let s = appState.snapshot {
                    Text("\(ByteSize.string(s.diskUsedBytes)) usati su \(ByteSize.string(s.diskTotalBytes))")
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(ByteSize.string(s.diskAvailableBytes)) liberi")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ok)
                } else {
                    Text("Lettura in corso…").foregroundStyle(Theme.textTertiary)
                }
                AccentButton(title: "Disinstalla app", systemImage: "trash") {
                    appState.section = .applications
                }
                .padding(.top, 6)
            }
            Spacer()
        }
        .card(padding: 24)
    }

    private var statRow: some View {
        HStack(spacing: 16) {
            if let s = appState.snapshot {
                StatTile(
                    icon: "internaldrive",
                    title: "DISCO",
                    value: ByteSize.string(s.diskAvailableBytes),
                    caption: "liberi",
                    fraction: s.diskUsedFraction
                )
                StatTile(
                    icon: "memorychip",
                    title: "MEMORIA",
                    value: "\(Int((s.ramUsedFraction * 100).rounded()))%",
                    caption: "\(ByteSize.string(s.ramUsedBytes)) usati",
                    fraction: s.ramUsedFraction
                )
                StatTile(
                    icon: "trash",
                    title: "CESTINO",
                    value: ByteSize.string(s.trashBytes),
                    caption: "svuotabile"
                )
            } else {
                ForEach(0..<3, id: \.self) { _ in
                    Color.clear.frame(height: 96).card()
                }
            }
        }
    }

    private var diskPercent: String {
        guard let s = appState.snapshot else { return "—" }
        return "\(Int((s.diskUsedFraction * 100).rounded()))%"
    }
}
