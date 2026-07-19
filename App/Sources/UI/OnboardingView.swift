import SwiftUI

/// Schermata di benvenuto al primo avvio: presenta l'app, la filosofia sicura e l'accento.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accentGradient)
                    .frame(width: 84, height: 84).shadow(color: Theme.accentMid.opacity(0.5), radius: 18)
                Image(systemName: "bolt.fill").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            }
            Text("Benvenuto in Destroyer").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Utility Mac open source: pulizia, spazio, prestazioni, protezione antimalware e privacy. Tutto va nel Cestino ed è reversibile.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.textSecondary).frame(maxWidth: 440)

            VStack(alignment: .leading, spacing: 10) {
                feature("trash", "Disinstallazione completa con residui di sistema")
                feature("shield.lefthalf.filled", "Antimalware con le firme XProtect di Apple")
                feature("arrow.uturn.backward", "Reversibile: Cestino, Undo e cronologia")
            }.padding(.vertical, 4)

            VStack(spacing: 8) {
                Text("Scegli il tuo accento").font(.caption).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 12) {
                    ForEach(0..<Theme.presetNames.count, id: \.self) { i in
                        Button { appState.setAccent(i) } label: {
                            Circle().fill(presetColor(i))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(.white, lineWidth: appState.accentPreset == i ? 2 : 0))
                        }.buttonStyle(.plain)
                    }
                }
            }

            AccentButton(title: "Inizia", systemImage: "arrow.right") { appState.finishOnboarding() }
        }
        .padding(36)
        .frame(width: 520, height: 560)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.accentSolid).frame(width: 22)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
        }
    }

    private func presetColor(_ i: Int) -> Color {
        [Color(hex: 0xFF4B57), Color(hex: 0x3AA0FF), Color(hex: 0x22C7A9), Color(hex: 0xFF4B4B)][i]
    }
}
