import Foundation

/// Scanner difensivo dei punti di persistenza (stile KnockKnock/BlockBlock di Objective-See).
/// Enumera LaunchAgents/LaunchDaemons e segnala quelli con indicatori sospetti.
/// NON è un antivirus a firme: è un rilevatore trasparente di persistenza indesiderata,
/// utile su QUALSIASI Mac (nessun percorso legato all'utente).
public struct ThreatScanner {

    private let fileManager: FileManager
    private let signer: CodeSignInspector
    private let home: URL

    public init(fileManager: FileManager = .default,
                signer: CodeSignInspector = CodeSignInspector(),
                home: URL? = nil) {
        self.fileManager = fileManager
        self.signer = signer
        self.home = (home ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
    }

    /// Posizioni standard dei launch item su macOS (escluso /System, gestito da Apple).
    private func launchDirectories() -> [(url: URL, system: Bool)] {
        [
            (home.appendingPathComponent("Library/LaunchAgents", isDirectory: true), false),
            (URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), true),
            (URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), true)
        ]
    }

    public func scan() -> [ThreatFinding] {
        var findings: [ThreatFinding] = []
        for (dir, isSystem) in launchDirectories() {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for plist in entries where plist.pathExtension == "plist" {
                if let finding = evaluate(plist: plist, isSystem: isSystem) {
                    findings.append(finding)
                }
            }
        }
        // Più gravi in cima.
        return findings.sorted { $0.severity > $1.severity }
    }

    /// Valuta un singolo launch item. Ritorna nil se non ci sono indicatori sospetti.
    private func evaluate(plist: URL, isSystem: Bool) -> ThreatFinding? {
        guard let dict = plistDict(plist) else { return nil }

        let label = (dict["Label"] as? String) ?? plist.deletingPathExtension().lastPathComponent
        let (programPath, arguments) = programAndArgs(dict)

        var reasons: [String] = []
        var severity: ThreatSeverity = .info
        // Un segnale "forte" indica comportamento davvero sospetto. La sola assenza di firma
        // NON è un segnale forte: troppi tool legittimi (dev, Homebrew, Docker…) non sono firmati.
        // Senza almeno un segnale forte NON produciamo un finding (evita falsi positivi).
        var strongSignal = false

        // 0) Corrispondenza con un indicatore noto di adware/PUP. (forte)
        if let indicator = KnownAdwareIndicators.match(label: label, path: programPath) {
            reasons.append("Corrisponde a un indicatore noto di adware/PUP: \(indicator)")
            severity = max(severity, .high); strongSignal = true
        }

        // 2) Percorso in posizione anomala (/tmp, cartelle nascoste…). (forte)
        if let p = programPath, isSuspiciousLocation(p) {
            reasons.append("Eseguibile in una posizione anomala: \(p)")
            severity = max(severity, .high); strongSignal = true
        }

        // 3) One-liner di shell negli argomenti (download/exec offuscato). (forte)
        if let bad = suspiciousArgument(arguments) {
            reasons.append("Comando sospetto negli argomenti: \(bad)")
            severity = max(severity, .high); strongSignal = true
        }

        // Segnali "deboli": aggiungono contesto solo se c'è già un segnale forte.
        if let p = programPath, !fileManager.fileExists(atPath: p) {
            reasons.append("L'eseguibile referenziato non esiste: \(p)")
        }
        if let p = programPath, fileManager.fileExists(atPath: p) {
            switch signer.inspect(path: p) {
            case .unsigned: reasons.append("Eseguibile non firmato o firma non valida")
            case .adhoc:    reasons.append("Firma ad-hoc (nessuna autorità verificabile)")
            case .valid, .unknown: break
            }
        }

        // Nessun segnale forte → nessun allarme (riduce i falsi positivi come da lezione Malwarebytes).
        guard strongSignal else { return nil }

        return ThreatFinding(
            title: label,
            itemURL: plist,
            programPath: programPath,
            reasons: reasons,
            severity: severity,
            requiresAuthorization: isSystem
        )
    }

    // MARK: - Parsing

    private func plistDict(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }
        return obj as? [String: Any]
    }

    private func programAndArgs(_ dict: [String: Any]) -> (String?, [String]) {
        let args = (dict["ProgramArguments"] as? [String]) ?? []
        let program = (dict["Program"] as? String) ?? args.first
        return (program, args)
    }

    // MARK: - Euristiche

    private func isSuspiciousLocation(_ path: String) -> Bool {
        let lower = path.lowercased()
        let flagged = ["/tmp/", "/private/tmp/", "/private/var/tmp/",
                       "/users/shared/", "/var/folders/"]
        if flagged.contains(where: { lower.hasPrefix($0) || lower.contains($0) }) { return true }
        // Componente nascosto (cartella che inizia con '.') fuori dalle Library standard.
        let comps = (path as NSString).pathComponents
        if comps.dropFirst().contains(where: { $0.hasPrefix(".") && $0 != ".Trash" }) { return true }
        return false
    }

    private func suspiciousArgument(_ args: [String]) -> String? {
        let needles = ["curl", "wget", "base64", "| sh", "|sh", "bash -c", "sh -c",
                       "python -c", "eval", "osascript -e", "nc ", "/dev/tcp"]
        let joined = args.joined(separator: " ").lowercased()
        for n in needles where joined.contains(n) {
            return n.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
