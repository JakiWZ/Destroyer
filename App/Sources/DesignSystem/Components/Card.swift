import SwiftUI

/// Superficie arrotondata con bordo sottile e ombra morbida.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var highlighted: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(highlighted ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

/// Modificatore rapido per "incartare" una vista in una Card.
extension View {
    func card(padding: CGFloat = 18, highlighted: Bool = false) -> some View {
        Card(padding: padding, highlighted: highlighted) { self }
    }
}
