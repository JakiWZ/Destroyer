import Foundation

/// Sposta gli item nel Cestino (reversibile). Non esegue MAI cancellazioni definitive.
/// Ogni rimozione è vincolata alla guardia `SafePaths`: un path non consentito viene
/// rifiutato con un errore, non ignorato silenziosamente.
public struct TrashService {

    public enum TrashError: Error, Equatable {
        /// Il path non ha superato la guardia di sicurezza.
        case blockedBySafety(URL)
        /// Errore del filesystem durante lo spostamento nel Cestino.
        case underlying(URL, String)
    }

    public typealias Outcome = RemovalOutcome

    private let safePaths: SafePaths
    private let fileManager: FileManager

    public init(safePaths: SafePaths = SafePaths(), fileManager: FileManager = .default) {
        self.safePaths = safePaths
        self.fileManager = fileManager
    }

    /// Sposta nel Cestino un singolo URL, applicando la guardia di sicurezza.
    @discardableResult
    public func trash(_ url: URL) throws -> URL {
        guard safePaths.isRemovable(url) else {
            throw TrashError.blockedBySafety(url)
        }
        var resulting: NSURL?
        do {
            try fileManager.trashItem(at: url, resultingItemURL: &resulting)
        } catch {
            throw TrashError.underlying(url, error.localizedDescription)
        }
        return (resulting as URL?) ?? url
    }

    /// Sposta nel Cestino una lista di URL, raccogliendo successi e fallimenti
    /// senza interrompersi al primo errore.
    /// Rimuove una lista di item, scaricando prima gli eventuali LaunchAgent utente.
    public func trashItems(_ items: [LeftoverItem]) -> Outcome {
        for item in items where LaunchctlService.isLaunchJob(item.category) {
            LaunchctlService.unloadUserAgent(item.url)
        }
        return trashAll(items.map(\.url))
    }

    public func trashAll(_ urls: [URL]) -> Outcome {
        var trashed: [URL] = []
        var failed: [RemovalOutcome.Failure] = []
        var moves: [RemovalOutcome.Move] = []
        for url in urls {
            do {
                let inTrash = try trash(url)
                trashed.append(inTrash)
                moves.append(.init(original: url, inTrash: inTrash))
            } catch let TrashError.blockedBySafety(u) {
                failed.append(.init(url: u, message: "Bloccato dalla guardia di sicurezza"))
            } catch let TrashError.underlying(u, msg) {
                failed.append(.init(url: u, message: msg))
            } catch {
                failed.append(.init(url: url, message: error.localizedDescription))
            }
        }
        return Outcome(trashed: trashed, failed: failed, moves: moves)
    }

    /// Annulla gli spostamenti riportando i file dalla loro posizione nel Cestino
    /// a quella originale. Ritorna il numero di elementi ripristinati.
    @discardableResult
    public func undo(_ moves: [RemovalOutcome.Move]) -> Int {
        var restored = 0
        for move in moves {
            // Ripristina solo se l'originale non è ricomparso e il file è ancora nel Cestino.
            guard fileManager.fileExists(atPath: move.inTrash.path),
                  !fileManager.fileExists(atPath: move.original.path) else { continue }
            do {
                try fileManager.moveItem(at: move.inTrash, to: move.original)
                restored += 1
            } catch {
                continue
            }
        }
        return restored
    }
}

/// Esito di una rimozione (condiviso tra rimozione normale e con autorizzazione).
public struct RemovalOutcome: Sendable {
    public struct Failure: Sendable {
        public let url: URL
        public let message: String
        public init(url: URL, message: String) {
            self.url = url
            self.message = message
        }
    }

    /// Spostamento reversibile: da dove veniva → dove si trova ora nel Cestino.
    public struct Move: Sendable {
        public let original: URL
        public let inTrash: URL
        public init(original: URL, inTrash: URL) {
            self.original = original
            self.inTrash = inTrash
        }
    }

    public let trashed: [URL]
    public let failed: [Failure]
    /// Spostamenti annullabili (solo rimozioni utente; gli item admin non sono annullabili).
    public let moves: [Move]

    public init(trashed: [URL], failed: [Failure], moves: [Move] = []) {
        self.trashed = trashed
        self.failed = failed
        self.moves = moves
    }

    public var totalTrashed: Int { trashed.count }
    public var canUndo: Bool { !moves.isEmpty }

    /// Unisce due esiti (es. rimozione normale + rimozione admin).
    public func merged(with other: RemovalOutcome) -> RemovalOutcome {
        RemovalOutcome(trashed: trashed + other.trashed,
                       failed: failed + other.failed,
                       moves: moves + other.moves)
    }

    public static let empty = RemovalOutcome(trashed: [], failed: [])
}
