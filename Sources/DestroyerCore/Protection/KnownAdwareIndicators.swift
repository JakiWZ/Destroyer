import Foundation

/// Lista APERTA ed estendibile di indicatori di adware/PUP noti su macOS.
/// Sono sottostringhe (case-insensitive) confrontate con label, path e nome file dei
/// launch item. Fonte: famiglie storicamente documentate (Genieo, VSearch, Pirrit,
/// MacKeeper, "cleaner" fasulli, ecc.). Contribuire = aggiungere voci qui.
public enum KnownAdwareIndicators {

    public static let identifiers: [String] = [
        "genieo", "vsearch", "pirrit", "mughthesec", "crossrider", "conduit",
        "installmac", "installcore", "spigot", "trovi", "searchprotect",
        "mackeeper", "advancedmaccleaner", "advanced mac cleaner", "maccleanup",
        "mac auto fixer", "mac cleanup pro", "smartmacfixer", "mediadownloader",
        "operativeengine", "adminprefs", "wizzsearch", "chilltab", "safefinder",
        "com.geeklab", "com.avaya", "amcinstaller", "systemspecial"
    ]

    /// Ritorna l'indicatore corrispondente (per la spiegazione all'utente), se presente.
    public static func match(label: String, path: String?) -> String? {
        let haystacks = [label.lowercased(), (path ?? "").lowercased()]
        for indicator in identifiers {
            if haystacks.contains(where: { $0.contains(indicator) }) {
                return indicator
            }
        }
        return nil
    }
}
