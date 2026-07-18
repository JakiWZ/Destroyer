import Foundation

/// Un'app installata individuata da `AppDiscovery` o trascinata dall'utente.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: URL { bundleURL }
    /// URL del bundle .app.
    public let bundleURL: URL
    /// Nome visibile (CFBundleName / CFBundleDisplayName, fallback: nome file senza .app).
    public let name: String
    /// Bundle identifier (CFBundleIdentifier), se presente.
    public let bundleIdentifier: String?
    /// Dimensione del bundle .app in byte (0 se non calcolata).
    public let sizeBytes: Int64

    public init(
        bundleURL: URL,
        name: String,
        bundleIdentifier: String?,
        sizeBytes: Int64 = 0
    ) {
        self.bundleURL = bundleURL
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.sizeBytes = sizeBytes
    }
}
