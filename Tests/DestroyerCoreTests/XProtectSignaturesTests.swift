import Testing
import Foundation
@testable import DestroyerCore

@Suite("XProtectSignatures — firme Apple")
struct XProtectSignaturesTests {

    /// Crea un XProtect.plist sintetico con una regola a pattern e la applica.
    @Test func matchesByBytePattern() {
        let fm = FileManager.default
        let hex = Array("EVILSIG".utf8).map { String(format: "%02X", $0) }.joined()
        let rule: [[String: Any]] = [[
            "Description": "OSX.Test.Synthetic",
            "Matches": [["MatchType": "Match", "Pattern": hex]]
        ]]
        let plist = fm.temporaryDirectory.appendingPathComponent("xp-\(UUID().uuidString).plist")
        let evil = fm.temporaryDirectory.appendingPathComponent("e-\(UUID().uuidString).bin")
        let clean = fm.temporaryDirectory.appendingPathComponent("c-\(UUID().uuidString).bin")
        defer { for u in [plist, evil, clean] { try? fm.removeItem(at: u) } }

        (rule as NSArray).write(to: plist, atomically: true)
        try? Data("xx EVILSIG yy".utf8).write(to: evil)
        try? Data("harmless".utf8).write(to: clean)

        let xp = XProtectSignatures(plistURL: plist)
        #expect(xp.ruleCount == 1)
        #expect(xp.match(fileURL: evil) == "OSX.Test.Synthetic")
        #expect(xp.match(fileURL: clean) == nil)
    }

    @Test func loadsRealSystemSignatures() {
        // Su un Mac reale XProtect è presente: almeno una regola.
        #expect(XProtectSignatures().ruleCount > 0)
    }
}
