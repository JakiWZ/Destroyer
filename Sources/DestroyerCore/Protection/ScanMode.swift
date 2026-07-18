import Foundation

/// Profondità della scansione antimalware (stile Moonlock: Rapida/Bilanciata/Profonda).
public enum ScanMode: String, CaseIterable, Sendable {
    case quick
    case balanced
    case deep

    public var title: String {
        switch self {
        case .quick:    return "Rapida"
        case .balanced: return "Bilanciata"
        case .deep:     return "Profonda"
        }
    }

    public var subtitle: String {
        switch self {
        case .quick:    return "Persistenza e processi attivi"
        case .balanced: return "+ app installate"
        case .deep:     return "+ Download, estensioni browser, volumi esterni"
        }
    }
}
