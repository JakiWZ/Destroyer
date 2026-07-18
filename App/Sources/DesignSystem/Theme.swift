import SwiftUI

/// Design system "Neon Destroyer" — tema scuro fisso, un solo gradiente accento
/// (magenta→arancio) usato con parsimonia su gauge, CTA e bordi attivi.
enum Theme {

    // MARK: - Colori base (tema scuro fisso)
    static let background      = Color(hex: 0x0E0E12)   // carbone
    static let backgroundDeep  = Color(hex: 0x08080B)   // sidebar / fondali
    static let surface         = Color(hex: 0x17171E)   // card
    static let surfaceElevated = Color(hex: 0x1F1F28)   // card in hover
    static let stroke          = Color.white.opacity(0.08)
    static let strokeStrong    = Color.white.opacity(0.16)

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary  = Color.white.opacity(0.38)

    // MARK: - Accento
    static let accentStart = Color(hex: 0xFF2D78)   // magenta
    static let accentMid   = Color(hex: 0xFF5A3C)   // rosso-arancio
    static let accentEnd   = Color(hex: 0xFF9A2E)   // arancio
    static let accentSolid = Color(hex: 0xFF4B57)

    static let accentGradient = LinearGradient(
        colors: [accentStart, accentMid, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Gradiente angolare per gli anelli (gauge).
    static let ringGradient = AngularGradient(
        colors: [accentStart, accentMid, accentEnd, accentStart],
        center: .center
    )

    // MARK: - Semantici (stato)
    static let ok      = Color(hex: 0x3ED598)
    static let warning = Color(hex: 0xFFB020)
    static let danger  = Color(hex: 0xFF4D4D)

    // MARK: - Metriche (look "tech": angoli più netti)
    static let corner: CGFloat = 12
    static let cornerSmall: CGFloat = 8
    static let spacing: CGFloat = 16

    // MARK: - Tipografia tech
    /// Font monospazio per readout tecnici (dimensioni, percentuali, path).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Sfondo a griglia tenue in stile HUD/tecnico.
struct TechGrid: View {
    var spacing: CGFloat = 28
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            ctx.stroke(path, with: .color(Theme.textPrimary.opacity(0.03)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Applica lo sfondo a griglia tech dietro la vista.
    func techGridBackground() -> some View {
        background(ZStack { Theme.background; TechGrid() })
    }
}

/// Etichetta stile terminale: "› TESTO" in monospazio, colore accento.
struct TechTag: View {
    let text: String
    var body: some View {
        Text("› \(text.uppercased())")
            .font(Theme.mono(10, weight: .semibold))
            .foregroundStyle(Theme.accentSolid)
            .tracking(1.2)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
