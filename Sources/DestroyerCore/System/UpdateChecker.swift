import Foundation

/// Controlla se esiste una versione più recente su GitHub Releases.
/// Nessuna dipendenza esterna: usa solo l'API pubblica. Sostituisci `repo` col tuo.
public struct UpdateChecker {

    public struct Result: Sendable {
        public let latestVersion: String
        public let isNewer: Bool
        public let releaseURL: URL
    }

    public enum CheckError: Error { case network, parse, notConfigured }

    /// owner/repo su GitHub. Vuoto = non configurato (controllo disabilitato).
    private let repo: String
    private let currentVersion: String
    private let session: URLSession

    public init(repo: String = "", currentVersion: String, session: URLSession = .shared) {
        self.repo = repo
        self.currentVersion = currentVersion
        self.session = session
    }

    public var isConfigured: Bool { !repo.isEmpty }

    public func check() async throws -> Result {
        guard isConfigured,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")
        else { throw CheckError.notConfigured }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CheckError.network
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlURL = (json["html_url"] as? String).flatMap(URL.init)
        else { throw CheckError.parse }

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Result(
            latestVersion: latest,
            isNewer: Self.isVersion(latest, newerThan: currentVersion),
            releaseURL: htmlURL
        )
    }

    /// Confronto semantico semplice "a.b.c".
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
