import Foundation
import CryptoKit

/// Calcolo hash di file per riferimento/visualizzazione (SHA-256).
///
/// Nota: il matching delle firme XProtect in questa versione è basato sui **pattern di byte**
/// (la maggioranza delle regole). Le regole basate su hash "Identity" di Apple usano SHA-1;
/// non le implementiamo per non introdurre SHA-1 — restano un'estensione futura.
public struct FileHasher {

    public init() {}

    /// SHA-256 (esadecimale) del contenuto del file. nil se illeggibile.
    public func sha256Hex(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
