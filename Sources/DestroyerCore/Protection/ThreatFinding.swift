import Foundation

/// Gravità di una segnalazione di sicurezza.
public enum ThreatSeverity: Int, Comparable, Sendable {
    case info = 0, low, medium, high

    public static func < (lhs: ThreatSeverity, rhs: ThreatSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .info:   return "Info"
        case .low:    return "Basso"
        case .medium: return "Medio"
        case .high:   return "Alto"
        }
    }
}

/// Come è stata rilevata la minaccia.
public enum DetectionType: String, Sendable {
    case persistence   // launch item sospetto (euristica di persistenza)
    case heuristic     // euristica sul file (firma/notarizzazione/posizione)
    case signature     // corrispondenza con una firma XProtect di Apple

    public var label: String {
        switch self {
        case .persistence: return "Persistenza"
        case .heuristic:   return "Euristica"
        case .signature:   return "Firma XProtect"
        }
    }
}

/// Una segnalazione: un elemento potenzialmente indesiderato/malevolo.
public struct ThreatFinding: Identifiable, Sendable {
    public let id: UUID
    /// Etichetta leggibile (Label del job o nome file).
    public let title: String
    /// Il file da ispezionare/rimuovere.
    public let itemURL: URL
    /// Percorso dell'eseguibile lanciato (se determinabile).
    public let programPath: String?
    /// Motivi della segnalazione (spiegazione trasparente per l'utente).
    public let reasons: [String]
    public let severity: ThreatSeverity
    /// Se true, rimuoverlo richiede autorizzazione admin (item di sistema).
    public let requiresAuthorization: Bool
    /// Come è stata rilevata.
    public let detection: DetectionType
    /// Famiglia malware (se rilevata per firma XProtect), es. "OSX.Genieo.E".
    public let family: String?

    public init(
        id: UUID = UUID(),
        title: String,
        itemURL: URL,
        programPath: String?,
        reasons: [String],
        severity: ThreatSeverity,
        requiresAuthorization: Bool,
        detection: DetectionType = .persistence,
        family: String? = nil
    ) {
        self.id = id
        self.title = title
        self.itemURL = itemURL
        self.programPath = programPath
        self.reasons = reasons
        self.severity = severity
        self.requiresAuthorization = requiresAuthorization
        self.detection = detection
        self.family = family
    }
}
