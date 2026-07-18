import Foundation

/// Un singolo file/cartella residuo candidato alla rimozione.
public struct LeftoverItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let category: LeftoverCategory
    /// Dimensione su disco in byte (0 se non calcolabile).
    public let sizeBytes: Int64
    /// Se true, l'item è protetto e NON deve essere selezionato di default né rimosso
    /// senza un'azione esplicita dell'utente (es. path fuori dalle aree consentite).
    public let isSystemProtected: Bool
    /// Se true, l'item è di sistema/root: rimuoverlo richiede l'autorizzazione admin
    /// (password). La UI mostra un lucchetto e la rimozione chiede il permesso.
    public let requiresAuthorization: Bool
    /// Stato di selezione nella review. Gli item protetti nascono deselezionati.
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        category: LeftoverCategory,
        sizeBytes: Int64,
        isSystemProtected: Bool,
        requiresAuthorization: Bool = false
    ) {
        self.id = id
        self.url = url
        self.category = category
        self.sizeBytes = sizeBytes
        self.isSystemProtected = isSystemProtected
        self.requiresAuthorization = requiresAuthorization
        self.isSelected = !isSystemProtected
    }
}
