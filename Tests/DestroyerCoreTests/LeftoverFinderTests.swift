import Testing
import Foundation
@testable import DestroyerCore

@Suite("LeftoverFinder — matching residui")
struct LeftoverFinderTests {

    /// Crea una home fittizia temporanea con residui noti, poi la pulisce.
    private func withFixture(_ body: (URL) throws -> Void) rethrows {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("dz-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: home) }
        try body(home)
    }

    private func write(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("x".utf8).write(to: url)
    }

    @Test func findsLeftoversByBundleIdAndName() {
        withFixture { home in
            let lib = home.appendingPathComponent("Library")
            write(lib.appendingPathComponent("Caches/com.acme.superapp/data.bin"))
            write(lib.appendingPathComponent("Preferences/com.acme.superapp.plist"))
            write(lib.appendingPathComponent("Application Support/SuperApp/state.json"))
            write(lib.appendingPathComponent("Caches/com.other.tool/noise.bin"))

            let app = InstalledApp(
                bundleURL: URL(fileURLWithPath: "/Applications/SuperApp.app"),
                name: "SuperApp", bundleIdentifier: "com.acme.superapp"
            )
            let items = LeftoverFinder(home: home).findLeftovers(for: app)

            #expect(items.contains { $0.url.path.contains("Caches/com.acme.superapp") })
            #expect(items.contains { $0.url.lastPathComponent == "com.acme.superapp.plist" })
            #expect(items.contains { $0.category == .appSupport })
            #expect(!items.contains { $0.url.path.contains("com.other.tool") })
        }
    }

    @Test func bundleIdMatchesAreSelectedNameOnlyAreNot() {
        withFixture { home in
            let lib = home.appendingPathComponent("Library")
            write(lib.appendingPathComponent("Caches/com.acme.superapp/data.bin"))
            write(lib.appendingPathComponent("Application Support/SuperApp/state.json"))

            let app = InstalledApp(
                bundleURL: URL(fileURLWithPath: "/Applications/SuperApp.app"),
                name: "SuperApp", bundleIdentifier: "com.acme.superapp"
            )
            let items = LeftoverFinder(home: home).findLeftovers(for: app)
            let cache = items.first { $0.category == .caches }
            let support = items.first { $0.category == .appSupport }
            #expect(cache?.isSelected == true)
            #expect(support?.isSelected == false)
        }
    }
}
