import Foundation

/// Rimozione dei file di sistema (root) tramite **autorizzazione admin**.
/// Mostra il pannello password di macOS e sposta gli item nel Cestino dell'utente
/// (reversibile). Ogni percorso è comunque validato da `SafePaths` prima di agire.
public struct AdminTrashService {

    public enum AdminError: Error, Equatable {
        case authorizationDenied      // l'utente ha annullato la richiesta password
        case failed(String)
    }

    private let safePaths: SafePaths
    private let trashURL: URL

    public init(safePaths: SafePaths = SafePaths(),
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.safePaths = safePaths
        self.trashURL = home.standardizedFileURL.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Sposta nel Cestino gli item indicati usando privilegi di amministratore.
    /// Un'unica richiesta di password copre l'intera lista; i LaunchDaemon/Agent
    /// di sistema vengono prima scaricati (bootout) nello stesso comando privilegiato.
    public func trash(_ items: [LeftoverItem]) -> RemovalOutcome {
        let allowed = items.filter { safePaths.isRemovable($0.url) }
        let blocked = items.filter { !safePaths.isRemovable($0.url) }
        var failed = blocked.map {
            RemovalOutcome.Failure(url: $0.url, message: "Bloccato dalla guardia di sicurezza")
        }
        guard !allowed.isEmpty else {
            return RemovalOutcome(trashed: [], failed: failed)
        }

        // 1) Scarica i job launchd di sistema. 2) Sposta ogni file nel Cestino utente.
        let unloads = allowed.compactMap {
            LaunchctlService.systemUnloadCommand(for: $0.url, category: $0.category)
        }
        let mkdir = "/bin/mkdir -p \(shellQuote(trashURL.path))"
        let moves = allowed.map { "/bin/mv -f \(shellQuote($0.url.path)) \(shellQuote(trashURL.path))/" }
        let command = (unloads + [mkdir] + moves).joined(separator: "; ")

        do {
            try runWithAdminPrivileges(command)
            return RemovalOutcome(trashed: allowed.map(\.url), failed: failed)
        } catch AdminError.authorizationDenied {
            failed += allowed.map { .init(url: $0.url, message: "Autorizzazione negata") }
            return RemovalOutcome(trashed: [], failed: failed)
        } catch {
            failed += allowed.map { .init(url: $0.url, message: "\(error)") }
            return RemovalOutcome(trashed: [], failed: failed)
        }
    }

    // MARK: - Esecuzione privilegiata via osascript

    private func runWithAdminPrivileges(_ shellCommand: String) throws {
        let script = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus != 0 else { return }

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""
        // Codice -128 / "User canceled" = l'utente ha annullato il prompt password.
        if errText.contains("-128") || errText.localizedCaseInsensitiveContains("canceled") {
            throw AdminError.authorizationDenied
        }
        throw AdminError.failed(errText.isEmpty ? "Errore sconosciuto" : errText)
    }

    /// Quoting sicuro per shell: racchiude in apici singoli, gestendo eventuali apici.
    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape per stringa letterale AppleScript (doppi apici): \ e ".
    private func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
