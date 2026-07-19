import Foundation
import DestroyerCore

// Destroyer CLI headless: scansioni e report scriptabili, adatti alla schedulazione vera
// (es. da cron/launchd) senza aprire la GUI.
//
// Uso:
//   destroyer scan            # scansione completa, stampa il report
//   destroyer scan --json     # report in JSON
//   destroyer clean           # sposta nel Cestino il junk trovato (reversibile)
//   destroyer protect         # solo scansione antimalware rapida
//   destroyer report <file>   # salva un report Markdown

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "scan"
let json = args.contains("--json")

func humanBytes(_ b: Int64) -> String { ByteSize.string(b) }

struct Report {
    var junkBytes: Int64 = 0
    var duplicatesReclaimable: Int64 = 0
    var threats: [ThreatFinding] = []
    var startupCount: Int = 0
}

func runScan() -> Report {
    var r = Report()
    r.junkBytes = JunkScanner().scan().reduce(0) { $0 + $1.totalBytes }
    r.duplicatesReclaimable = FileInsightScanner().duplicates().reduce(0) { $0 + $1.reclaimableBytes }
    r.threats = MalwareScanner().scan(mode: .quick)
    r.startupCount = LoginItemsScanner().scan().count
    return r
}

func printReport(_ r: Report) {
    if json {
        let obj: [String: Any] = [
            "junkBytes": r.junkBytes,
            "duplicatesReclaimableBytes": r.duplicatesReclaimable,
            "threats": r.threats.map { ["title": $0.title, "severity": $0.severity.label, "detection": $0.detection.label] },
            "startupItems": r.startupCount
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    } else {
        print("Destroyer — report")
        print("  Junk pulibile:        \(humanBytes(r.junkBytes))")
        print("  Duplicati recuperabili: \(humanBytes(r.duplicatesReclaimable))")
        print("  Minacce:              \(r.threats.count)")
        for t in r.threats { print("    · [\(t.severity.label)] \(t.title)") }
        print("  Elementi di avvio:    \(r.startupCount)")
    }
}

func markdown(_ r: Report) -> String {
    var s = "# Report Destroyer\n\n"
    s += "- **Junk pulibile:** \(humanBytes(r.junkBytes))\n"
    s += "- **Duplicati recuperabili:** \(humanBytes(r.duplicatesReclaimable))\n"
    s += "- **Elementi di avvio:** \(r.startupCount)\n"
    s += "- **Minacce:** \(r.threats.count)\n"
    for t in r.threats { s += "  - [\(t.severity.label)] \(t.title) — \(t.reasons.first ?? "")\n" }
    return s
}

switch command {
case "scan":
    printReport(runScan())
case "protect":
    let threats = MalwareScanner().scan(mode: .quick)
    print("Minacce: \(threats.count)")
    for t in threats { print("  · [\(t.severity.label)] \(t.title)") }
case "clean":
    let urls = JunkScanner().scan().flatMap { $0.items }.filter(\.isSelected).map(\.url)
    let outcome = TrashService().trashAll(urls)
    print("Spostati nel Cestino: \(outcome.totalTrashed) elementi (\(outcome.failed.count) non riusciti)")
case "report":
    let path = args.dropFirst().first ?? "destroyer-report.md"
    try? markdown(runScan()).data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
    print("Report salvato: \(path)")
default:
    print("Comandi: scan [--json] | protect | clean | report <file>")
}
