import Foundation

/// Legge e applica le firme **XProtect di Apple** (già presenti e auto-aggiornate su ogni Mac).
/// Formato `XProtect.plist`: array di regole; ogni regola ha `Description` (famiglia) e `Matches`.
/// Un match ha `MatchType` (Match/MatchAny/MatchAll), un eventuale `Pattern` (byte in esadecimale
/// da cercare nel file) e/o `Matches` annidati. Qui applichiamo il matching **basato sui pattern**.
public struct XProtectSignatures {

    /// Nodo dell'albero di match di una regola.
    private struct Node {
        let matchType: String?      // "Match", "MatchAny", "MatchAll"
        let pattern: Data?          // sequenza di byte da cercare (nil se non rappresentabile)
        let hasIdentityOnly: Bool   // leaf basato solo su hash (non supportato → non-match)
        let children: [Node]
    }

    private struct Rule {
        let family: String
        let nodes: [Node]           // ANDati tra loro (tutti devono valere)
    }

    private let rules: [Rule]
    /// Non leggere file più grandi di questa soglia (bound su tempo/memoria).
    private let maxScanBytes: Int

    public var ruleCount: Int { rules.count }

    /// - Parameter plistURL: percorso di XProtect.plist. Se nil, prova i percorsi canonici.
    public init(plistURL: URL? = nil, maxScanBytes: Int = 256 * 1024 * 1024) {
        self.maxScanBytes = maxScanBytes
        let url = plistURL ?? Self.locateXProtectPlist()
        self.rules = url.flatMap(Self.parse(plistAt:)) ?? []
    }

    /// Ritorna il nome della famiglia se il file corrisponde a una firma, altrimenti nil.
    public func match(fileURL: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > 0, size <= maxScanBytes,
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        else { return nil }

        for rule in rules {
            if rule.nodes.allSatisfy({ evaluate($0, in: data) }) {
                return rule.family
            }
        }
        return nil
    }

    // MARK: - Valutazione

    private func evaluate(_ node: Node, in data: Data) -> Bool {
        if !node.children.isEmpty {
            if node.matchType == "MatchAny" {
                return node.children.contains { evaluate($0, in: data) }
            }
            return node.children.allSatisfy { evaluate($0, in: data) }
        }
        // Foglia: supportiamo solo i pattern di byte.
        if let pattern = node.pattern {
            return data.range(of: pattern) != nil
        }
        // Foglia basata solo su hash (Identity): non supportata → non-match.
        return false
    }

    // MARK: - Parsing

    private static func parse(plistAt url: URL) -> [Rule]? {
        guard let data = try? Data(contentsOf: url),
              let arr = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]]
        else { return nil }

        return arr.compactMap { dict in
            guard let family = dict["Description"] as? String,
                  let matches = dict["Matches"] as? [[String: Any]] else { return nil }
            let nodes = matches.map(node(from:))
            return Rule(family: family, nodes: nodes)
        }
    }

    private static func node(from dict: [String: Any]) -> Node {
        let type = dict["MatchType"] as? String
        let children = (dict["Matches"] as? [[String: Any]])?.map(node(from:)) ?? []
        let pattern = (dict["Pattern"] as? String).flatMap(hexToData)
        let hasIdentityOnly = dict["Identity"] != nil && pattern == nil && children.isEmpty
        return Node(matchType: type, pattern: pattern, hasIdentityOnly: hasIdentityOnly, children: children)
    }

    /// Converte una stringa esadecimale ("3A6C61…") in Data. nil se malformata.
    private static func hexToData(_ hex: String) -> Data? {
        let clean = hex.filter { $0.isHexDigit }
        guard clean.count % 2 == 0, !clean.isEmpty else { return nil }
        var out = Data(capacity: clean.count / 2)
        var idx = clean.startIndex
        while idx < clean.endIndex {
            let next = clean.index(idx, offsetBy: 2)
            guard let byte = UInt8(clean[idx..<next], radix: 16) else { return nil }
            out.append(byte)
            idx = next
        }
        return out
    }

    /// Percorsi canonici di XProtect.plist su macOS moderni (in ordine di preferenza).
    private static func locateXProtectPlist() -> URL? {
        let candidates = [
            "/var/db/SystemPolicyConfiguration/XProtect.bundle/Contents/Resources/XProtect.plist",
            "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.plist",
            "/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.plist"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }
}
