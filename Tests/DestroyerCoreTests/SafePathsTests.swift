import Testing
import Foundation
@testable import DestroyerCore

@Suite("SafePaths — guardia di sicurezza")
struct SafePathsTests {

    // Home fittizia isolata, così i test non dipendono dalla macchina.
    let sut = SafePaths(home: URL(fileURLWithPath: "/Users/tester", isDirectory: true))

    private func u(_ path: String) -> URL { URL(fileURLWithPath: path) }

    // MARK: - Percorsi consentiti

    @Test func allowsFileInsideUserCaches() {
        #expect(sut.isRemovable(u("/Users/tester/Library/Caches/com.acme.App")))
    }

    @Test func allowsPreferencePlist() {
        #expect(sut.isRemovable(u("/Users/tester/Library/Preferences/com.acme.App.plist")))
    }

    @Test func allowsAppBundleInApplications() {
        #expect(sut.isRemovable(u("/Applications/Acme.app")))
    }

    @Test func allowsSystemLibraryLaunchAgentEntry() {
        #expect(sut.isRemovable(u("/Library/LaunchAgents/com.acme.helper.plist")))
    }

    @Test func allowsSystemLaunchDaemon() {
        #expect(sut.isRemovable(u("/Library/LaunchDaemons/com.acme.helper.plist")))
    }

    @Test func allowsPrivilegedHelperTool() {
        #expect(sut.isRemovable(u("/Library/PrivilegedHelperTools/com.acme.helper")))
    }

    @Test func rejectsSystemLaunchDaemons() {
        #expect(!sut.isRemovable(u("/System/Library/LaunchDaemons/com.apple.x.plist")))
    }

    @Test func rejectsLaunchDaemonsRootItself() {
        #expect(!sut.isRemovable(u("/Library/LaunchDaemons")))
    }

    // MARK: - Percorsi vietati (sistema)

    @Test func rejectsSystemDirectory() {
        #expect(!sut.isRemovable(u("/System/Library/CoreServices/Finder.app")))
    }

    @Test func rejectsUsrBin() {
        #expect(!sut.isRemovable(u("/usr/bin/swift")))
    }

    @Test func rejectsLibraryApple() {
        #expect(!sut.isRemovable(u("/Library/Apple/System/whatever")))
    }

    @Test func rejectsApplicationsUtilities() {
        #expect(!sut.isRemovable(u("/Applications/Utilities/Terminal.app")))
    }

    // MARK: - Mai svuotare le root stesse

    @Test func rejectsCachesRootItself() {
        #expect(!sut.isRemovable(u("/Users/tester/Library/Caches")))
    }

    @Test func rejectsLibraryRootItself() {
        #expect(!sut.isRemovable(u("/Users/tester/Library")))
    }

    @Test func rejectsApplicationsRootItself() {
        #expect(!sut.isRemovable(u("/Applications")))
    }

    @Test func rejectsFilesystemRoot() {
        #expect(!sut.isRemovable(u("/")))
    }

    // MARK: - Trucchi / traversal / prefissi ingannevoli

    @Test func rejectsPathTraversalEscapingAllowedRoot() {
        #expect(!sut.isRemovable(u("/Users/tester/Library/Caches/../../../etc/passwd")))
    }

    @Test func allowsFilesInsideHome() {
        #expect(sut.isRemovable(u("/Users/tester/Downloads/big.dmg")))
        #expect(sut.isRemovable(u("/Users/tester/Library/Safari/History.db")))
    }

    @Test func rejectsProtectedHomeRoots() {
        #expect(!sut.isRemovable(u("/Users/tester/Downloads")))
        #expect(!sut.isRemovable(u("/Users/tester/Documents")))
        #expect(!sut.isRemovable(u("/Users/tester/Library/Keychains/login.keychain-db")))
    }

    @Test func rejectsAnotherUsersHome() {
        #expect(!sut.isRemovable(u("/Users/altro/Library/Caches/com.acme.App")))
    }

    // MARK: - Eccezione /usr/local

    @Test func usrLocalStaysNonRemovableUnlessInAllowlist() {
        #expect(!sut.isRemovable(u("/usr/local/bin/brew")))
    }
}
