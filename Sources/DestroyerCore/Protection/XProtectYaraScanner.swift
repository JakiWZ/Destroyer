import Foundation

/// Applica le regole **YARA di XProtect** (`XProtect.yara`) usando il binario `yara` se presente
/// (es. installato via Homebrew). Copertura extra rispetto al matching per pattern.
/// Degrada in modo elegante: se `yara` non è installato, `isAvailable` è false e non fa nulla.
public struct XProtectYaraScanner {

    private let yaraPath: String?
    private let rulesPath: String?

    public init() {
        self.yaraPath = ["/opt/homebrew/bin/yara", "/usr/local/bin/yara"]
            .first { FileManager.default.fileExists(atPath: $0) }
        self.rulesPath = [
            "/var/db/SystemPolicyConfiguration/XProtect.bundle/Contents/Resources/XProtect.yara",
            "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.yara"
        ].first { FileManager.default.fileExists(atPath: $0) }
    }

    public var isAvailable: Bool { yaraPath != nil && rulesPath != nil }

    /// Ritorna i nomi delle regole YARA che matchano il file (vuoto se nessuna o non disponibile).
    public func match(fileURL: URL) -> [String] {
        guard let yara = yaraPath, let rules = rulesPath else { return [] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: yara)
        // `-f` fast, `-w` no warnings; stampa "<rule> <file>" per ogni match.
        p.arguments = ["-f", "-w", rules, fileURL.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return [] }
        return out.split(separator: "\n").compactMap { line in
            line.split(separator: " ").first.map(String.init)
        }
    }
}
