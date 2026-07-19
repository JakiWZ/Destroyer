import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                smartScanCard
                if appState.healthHistory.count > 1 { trendCard }
                heroCard
                statRow
            }
            .padding(28)
        }
        .techGridBackground()
    }

    @State private var showHistory = false

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                TechTag(text: "system status")
                Text("Stato del tuo Mac")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            HStack(spacing: 8) {
                GhostButton(title: "Cronologia", systemImage: "clock.arrow.circlepath") { showHistory = true }
                GhostButton(title: "Report", systemImage: "square.and.arrow.up") { exportReport() }
            }
        }
        .sheet(isPresented: $showHistory) { HistoryView() }
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "destroyer-report.md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            appState.exportReport(to: url)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TechTag(text: "health trend")
            Chart(appState.healthHistory) { p in
                LineMark(x: .value("Data", p.date), y: .value("Salute", p.score))
                    .foregroundStyle(Theme.accentGradient)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Data", p.date), y: .value("Salute", p.score))
                    .foregroundStyle(Theme.accentSolid.opacity(0.12))
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 120)
        }
        .card(padding: 18)
    }

    private var smartScanCard: some View {
        HStack(spacing: 24) {
            if let r = appState.smartResult {
                GaugeRing(value: Double(r.healthScore) / 100, lineWidth: 14) {
                    VStack(spacing: 0) {
                        Text("\(r.healthScore)").font(Theme.mono(30, weight: .bold)).foregroundStyle(Theme.textPrimary)
                        Text("salute").font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }.frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    TechTag(text: "smart scan")
                    Text(smartLabel(r.healthScore)).font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Junk \(ByteSize.string(r.junkBytes)) · \(r.threatCount) minacce · \(r.startupCount) avvii")
                        .font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 10) {
                        if r.junkBytes > 0 {
                            AccentButton(title: "Correggi tutto", systemImage: "wand.and.stars") { appState.fixAll() }
                        }
                        GhostButton(title: "Riesegui", systemImage: "arrow.clockwise") { appState.smartScan() }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TechTag(text: "smart scan")
                    Text("Un click: Pulizia · Protezione · Prestazioni")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Analisi rapida con punteggio di salute complessivo.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if appState.isSmartScanning {
                    ProgressView().controlSize(.large)
                } else {
                    AccentButton(title: "Smart Scan", systemImage: "sparkles.rectangle.stack") { appState.smartScan() }
                }
            }
            Spacer()
        }
        .card(padding: 22, highlighted: true)
    }

    private func smartLabel(_ s: Int) -> String {
        s >= 85 ? "Il tuo Mac è in ottima forma" : (s >= 60 ? "Qualche intervento consigliato" : "Attenzione: interventi necessari")
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
