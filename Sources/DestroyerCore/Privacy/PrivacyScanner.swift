import Foundation

/// Un elemento di privacy rimovibile (cache/cookie/cronologia di un browser).
public struct PrivacyItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let browser: String
    public let kind: String        // "Cache", "Cookie", "Cronologia"
    public let url: URL
    public let sizeBytes: Int64
    public var isSelected: Bool

    public init(browser: String, kind: String, url: URL, sizeBytes: Int64, isSelected: Bool = false) {
        self.browser = browser
        self.kind = kind
        self.url = url
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
    }
}

/// Individua i dati di navigazione dei browser installati. Sola lettura; la rimozione
/// avviene poi via Cestino (guardia `SafePaths`). Riconosce i browser più comuni.
public struct PrivacyScanner {
    private let fileManager: FileManager
    private let scanner: FileScanner
    private let home: URL

    public init(fileManager: FileManager = .default, home: URL? = nil) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
        self.home = (home ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
    }

    private struct Source { let browser: String; let kind: String; let relPath: String }

    private var sources: [Source] {
        [
            .init(browser: "Safari", kind: "Cronologia", relPath: "Library/Safari/History.db"),
            .init(browser: "Safari", kind: "Cache", relPath: "Library/Caches/com.apple.Safari"),
            .init(browser: "Chrome", kind: "Cache", relPath: "Library/Caches/Google/Chrome"),
            .init(browser: "Chrome", kind: "Cookie", relPath: "Library/Application Support/Google/Chrome/Default/Cookies"),
            .init(browser: "Chrome", kind: "Cronologia", relPath: "Library/Application Support/Google/Chrome/Default/History"),
            .init(browser: "Brave", kind: "Cache", relPath: "Library/Caches/BraveSoftware/Brave-Browser"),
            .init(browser: "Brave", kind: "Cookie", relPath: "Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies"),
            .init(browser: "Edge", kind: "Cache", relPath: "Library/Caches/Microsoft Edge"),
            .init(browser: "Firefox", kind: "Cache", relPath: "Library/Caches/Firefox"),
            // Privacy di sistema.
            .init(browser: "Sistema", kind: "Elementi recenti", relPath: "Library/Application Support/com.apple.sharedfilelist"),
            .init(browser: "Sistema", kind: "Cache QuickLook", relPath: "Library/Caches/com.apple.QuickLook.thumbnailcache")
        ]
    }

    public func scan() -> [PrivacyItem] {
        var out: [PrivacyItem] = []
        for s in sources {
            let url = home.appendingPathComponent(s.relPath)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let size = scanner.size(of: url)
            guard size > 0 else { continue }
            out.append(PrivacyItem(browser: s.browser, kind: s.kind, url: url, sizeBytes: size))
        }
        return out.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
