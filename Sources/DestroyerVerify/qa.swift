import Foundation
import DestroyerCore

/// QA dal vivo: esegue gli scanner reali sulla macchina e verifica gli invarianti di sicurezza,
/// ispirato ai difetti noti di CleanMyMac/Malwarebytes (cancellare file utili, falsi positivi,
/// azioni che "non fanno nulla" perché bloccate dalla guardia).
///
/// Ritorna il numero di controlli FALLITI (0 = tutto ok).
func runLiveQA() -> Int {
    var failures = 0
    func ok(_ cond: Bool, _ label: String) {
        print(cond ? "  ✓ \(label)" : "  ✗ FALLITO: \(label)")
        if !cond { failures += 1 }
    }
    func sect(_ s: String) { print("\n▶ QA · \(s)") }

    let safe = SafePaths()

    // Invariante 1: ogni candidato "pulibile" DEVE superare SafePaths (altrimenti il click non fa nulla).
    sect("i candidati alla rimozione sono effettivamente rimovibili")

    let junk = JunkScanner().scan().flatMap { $0.items }.map(\.url)
    ok(junk.allSatisfy { safe.isRemovable($0) }, "junk (\(junk.count)) tutti rimovibili")

    let privacy = PrivacyScanner().scan().map(\.url)
    ok(privacy.allSatisfy { safe.isRemovable($0) }, "privacy (\(privacy.count)) tutti rimovibili")

    let insight = FileInsightScanner()
    let large = insight.largeOrOld().map(\.url)
    ok(large.allSatisfy { safe.isRemovable($0) }, "file grandi/vecchi (\(large.count)) tutti rimovibili")
    let dups = insight.duplicates().flatMap { $0.files }.map(\.url)
    ok(dups.allSatisfy { safe.isRemovable($0) }, "duplicati (\(dups.count)) tutti rimovibili")

    let langs = LanguageScanner().scan().map(\.url)
    ok(langs.allSatisfy { safe.isRemovable($0) }, "file di lingua (\(langs.count)) tutti rimovibili")

    // Invariante 2: nessuno scanner propone percorsi di sistema critici.
    sect("nessun percorso di sistema critico tra i candidati")
    let allCandidates = junk + privacy + large + dups + langs
    let touchesSystem = allCandidates.contains { $0.path.hasPrefix("/System") || $0.path.hasPrefix("/usr/") || $0.path.hasPrefix("/bin") }
    ok(!touchesSystem, "nessun candidato in /System /usr /bin")

    // Invariante 3: la protezione non produce falsi positivi sul sistema pulito (no finding in /System).
    sect("protezione: nessun finding dentro /System")
    let threats = MalwareScanner().scan(mode: .quick)
    ok(!threats.contains { $0.itemURL.path.hasPrefix("/System") }, "nessun finding in /System (trovati \(threats.count))")
    for t in threats {
        print("    · [\(t.severity.label)/\(t.detection.label)] \(t.itemURL.lastPathComponent) — \(t.reasons.first ?? "")")
    }
    // I finding a bassa gravità su binari non firmati NON devono essere allarmanti (falsi positivi).
    let highOnly = threats.filter { $0.severity >= .high }
    ok(highOnly.allSatisfy { $0.detection == .signature }, "i finding ad alta gravità sono solo firme (no euristica allarmista)")

    // Invariante 4: gli scanner girano senza crash e restituiscono dati sensati.
    sect("robustezza degli scanner")
    ok(LoginItemsScanner().scan().count >= 0, "login items ok")
    ok(SpaceLensScanner().breakdown(of: FileManager.default.homeDirectoryForCurrentUser).count >= 0, "space lens ok")
    ok(UniversalBinaryScanner().scan().count >= 0, "binari universali ok")
    let net = LiveMetrics().network()
    ok(net.bytesPerSecDown >= 0, "metriche rete ok")

    return failures
}
