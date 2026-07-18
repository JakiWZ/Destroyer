import SwiftUI

/// Anello circolare animato con gradiente accento e contenuto centrale libero.
struct GaugeRing<Center: View>: View {
    /// Valore in [0, 1].
    var value: Double
    var lineWidth: CGFloat = 16
    @ViewBuilder var center: () -> Center

    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.strokeStrong, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animated)
                .stroke(
                    Theme.ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accentMid.opacity(0.5), radius: 8)

            center()
        }
        .onAppear { animate(to: value) }
        .onChange(of: value) { _, newValue in animate(to: newValue) }
    }

    private func animate(to v: Double) {
        withAnimation(.easeOut(duration: 0.9)) {
            animated = min(1, max(0, v))
        }
    }
}

extension GaugeRing where Center == EmptyView {
    init(value: Double, lineWidth: CGFloat = 16) {
        self.init(value: value, lineWidth: lineWidth) { EmptyView() }
    }
}
