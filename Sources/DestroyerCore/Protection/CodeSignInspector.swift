import Foundation

/// Verifica la firma del codice di un eseguibile tramite `codesign`.
/// Un eseguibile di persistenza non firmato (o con firma non valida) è un indicatore
/// classico di adware/malware su macOS.
public struct CodeSignInspector {

    public enum Signature: Sendable {
        case valid          // firmato e verificato
        case adhoc          // firma ad-hoc (nessuna autorità)
        case unsigned       // non firmato / firma non valida
        case unknown        // impossibile determinare (file assente)
    }

    public init() {}

    public func inspect(path: String) -> Signature {
        guard FileManager.default.fileExists(atPath: path) else { return .unknown }

        // `codesign --verify` esce 0 se la firma è valida.
        if run(["/usr/bin/codesign", "--verify", "--deep", "--strict", path]) == 0 {
            // Distingui ad-hoc (TeamIdentifier assente) da firma piena.
            let info = runCapture(["/usr/bin/codesign", "-dv", path])
            if info.contains("Signature=adhoc") { return .adhoc }
            return .valid
        }
        return .unsigned
    }

    // MARK: - Process helpers

    private func run(_ argv: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private func runCapture(_ argv: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return "" }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
