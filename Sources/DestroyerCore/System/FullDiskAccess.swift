import Foundation

/// Rileva (sola lettura) se l'app ha il permesso Full Disk Access.
/// Serve per leggere i residui nelle Library di ALTRE app.
///
/// Tecnica: si prova a leggere un percorso protetto da TCC che è accessibile
/// solo con Full Disk Access. Se la lettura fallisce per permessi → non concesso.
public enum FullDiskAccess {

    /// Percorsi protetti usati come sonda (basta che UNO sia leggibile).
    private static var probePaths: [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Library/Application Support/com.apple.TCC/TCC.db",
            home + "/Library/Safari/CloudTabs.db",
            home + "/Library/Safari/Bookmarks.plist"
        ]
    }

    /// Vero se l'app può leggere aree protette (Full Disk Access concesso).
    public static func isGranted() -> Bool {
        let fm = FileManager.default
        for path in probePaths {
            // Il file deve esistere e deve essere apribile in lettura.
            guard fm.fileExists(atPath: path) else { continue }
            if let handle = FileHandle(forReadingAtPath: path) {
                try? handle.close()
                return true
            } else {
                // Esiste ma non è leggibile → permesso negato.
                return false
            }
        }
        // Nessuna sonda presente (Mac senza Safari, ecc.): non possiamo
        // dimostrare il diniego, quindi non blocchiamo inutilmente.
        return true
    }

    /// URL per aprire direttamente il pannello Full Disk Access in Impostazioni di Sistema.
    public static var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    }
}
