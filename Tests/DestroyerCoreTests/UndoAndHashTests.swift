import Testing
import Foundation
@testable import DestroyerCore

@Suite("Undo & Hash & Impatto avvio")
struct UndoAndHashTests {

    private func tmpDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("dz-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private func write(_ url: URL, _ s: String = "x") { try? Data(s.utf8).write(to: url) }

    @Test func undoRestoresFile() {
        let d = tmpDir(); defer { try? FileManager.default.removeItem(at: d) }
        let orig = d.appendingPathComponent("orig")
        let inTrash = d.appendingPathComponent("intrash"); write(inTrash)
        let n = TrashService().undo([RemovalOutcome.Move(original: orig, inTrash: inTrash)])
        #expect(n == 1)
        #expect(FileManager.default.fileExists(atPath: orig.path))
        #expect(!FileManager.default.fileExists(atPath: inTrash.path))
    }

    @Test func undoDoesNotOverwriteExistingOriginal() {
        let d = tmpDir(); defer { try? FileManager.default.removeItem(at: d) }
        let orig = d.appendingPathComponent("orig"); write(orig, "esistente")
        let inTrash = d.appendingPathComponent("intrash"); write(inTrash, "nuovo")
        #expect(TrashService().undo([RemovalOutcome.Move(original: orig, inTrash: inTrash)]) == 0)
    }

    @Test func hashesAreDeterministic() {
        let d = tmpDir(); defer { try? FileManager.default.removeItem(at: d) }
        let a = d.appendingPathComponent("a"); write(a, "same")
        let b = d.appendingPathComponent("b"); write(b, "same")
        let c = d.appendingPathComponent("c"); write(c, "diff")
        let h = FileHasher()
        #expect(h.sha256Hex(of: a) == h.sha256Hex(of: b))
        #expect(h.sha256Hex(of: a) != h.sha256Hex(of: c))
    }

    @Test func removalOutcomeMerge() {
        let m = RemovalOutcome.Move(original: URL(fileURLWithPath: "/a"), inTrash: URL(fileURLWithPath: "/b"))
        let o1 = RemovalOutcome(trashed: [URL(fileURLWithPath: "/b")], failed: [], moves: [m])
        let o2 = RemovalOutcome(trashed: [], failed: [.init(url: URL(fileURLWithPath: "/c"), message: "no")], moves: [])
        let merged = o1.merged(with: o2)
        #expect(merged.totalTrashed == 1)
        #expect(merged.failed.count == 1)
        #expect(merged.canUndo)
    }
}
