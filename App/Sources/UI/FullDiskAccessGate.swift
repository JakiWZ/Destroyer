import SwiftUI

/// Gate a schermo intero: resta visibile finché Full Disk Access non è concesso.
/// Mostra istruzioni, un pulsante per aprire le Impostazioni e ricontrolla da solo.
struct FullDiskAccessGate: View {
    @EnvironmentObject var appState: AppState
    /// Timer di polling: ricontrolla il permesso ogni 1.5s finché non è concesso.
    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Sfondo scuro che oscura e blocca l'app sottostante.
            Theme.background.opacity(0.96).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Theme.accentGradient).frame(width: 72, height: 72)
                        .shadow(color: Theme.accentMid.opacity(0.5), radius: 16)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("Concedi l'accesso completo al disco")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Destroyer ha bisogno di **Accesso completo al disco** per trovare i file residui nelle Library delle altre app. Nessun dato lascia il tuo Mac.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: 420)
                }

                steps

                VStack(spacing: 10) {
                    AccentButton(title: "Apri Impostazioni di Sistema", systemImage: "gearshape.fill") {
                        appState.openFullDiskAccessSettings()
                    }
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("In attesa dell'autorizzazione…")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    GhostButton(title: "Ho già concesso — ricontrolla", systemImage: "arrow.clockwise") {
                        appState.recheckAccess()
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: 520)
            .card(padding: 36, highlighted: true)
            .padding(40)
        }
        .onReceive(poll) { _ in appState.recheckAccess() }
        .transition(.opacity)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Apri **Privacy e sicurezza → Accesso completo al disco**")
            step(2, "Attiva l'interruttore accanto a **Destroyer**")
            step(3, "Torna qui: l'app si sblocca da sola")
        }
        .padding(16)
        .frame(maxWidth: 420, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).strokeBorder(Theme.stroke))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.accentGradient))
            Text(.init(text))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
