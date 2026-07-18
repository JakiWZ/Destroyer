import Testing
import Foundation
@testable import DestroyerCore

@Suite("TrashService & UpdateChecker")
struct TrashServiceTests {

    @Test func blocksSystemPaths() {
        let sut = TrashService(safePaths: SafePaths(home: URL(fileURLWithPath: "/Users/tester")))
        #expect(throws: TrashService.TrashError.self) {
            try sut.trash(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        }
    }

    @Test func trashAllReportsBlockedFailures() {
        let sut = TrashService(safePaths: SafePaths(home: URL(fileURLWithPath: "/Users/tester")))
        let outcome = sut.trashAll([URL(fileURLWithPath: "/usr/bin/swift")])
        #expect(outcome.trashed.isEmpty)
        #expect(outcome.failed.count == 1)
    }

    @Test func versionComparison() {
        #expect(UpdateChecker.isVersion("1.2.0", newerThan: "1.1.9"))
        #expect(UpdateChecker.isVersion("0.2.0", newerThan: "0.1.0"))
        #expect(!UpdateChecker.isVersion("0.1.0", newerThan: "0.1.0"))
        #expect(!UpdateChecker.isVersion("0.1.0", newerThan: "0.2.0"))
    }
}
