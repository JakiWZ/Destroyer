import SwiftUI

/// Mini-metrica: icona + valore grande + label, con barra di riempimento opzionale.
struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    var caption: String? = nil
    /// Frazione [0,1] per la barra; nil = nessuna barra.
    var fraction: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentSolid)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.strokeStrong)
                        Capsule()
                            .fill(Theme.accentGradient)
                            .frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 6)
            }

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}
