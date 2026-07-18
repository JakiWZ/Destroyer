import Foundation

/// File di localizzazione (`.lproj`) inutili dentro le app: le lingue che non usi.
/// ATTENZIONE: rimuoverli può invalidare la firma dell'app; per questo vanno solo nel Cestino
/// (reversibile) e sono deselezionati/segnalati come delicati.
public struct LanguageFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let appName: String
    public let language: String
    public let url: URL
    public let sizeBytes: Int64
    public var isSelected: Bool

    public init(appName: String, language: String, url: URL, sizeBytes: Int64, isSelected: Bool = false) {
        self.appName = appName; self.language = language; self.url = url
        self.sizeBytes = sizeBytes; self.isSelected = isSelected
    }
}

public struct LanguageScanner {
    private let fileManager: FileManager
    private let scanner: FileScanner
    private let appDirs: [URL]
    private let keep: Set<String>

    public init(fileManager: FileManager = .default, appDirs: [URL]? = nil) {
        self.fileManager = fileManager
        self.scanner = FileScanner(fileManager: fileManager)
        self.appDirs = appDirs ?? [URL(fileURLWithPath: "/Applications"),
                                   fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        // Lingue da tenere: preferite di sistema + Base + inglese.
        var k: Set<String> = ["Base", "en"]
        for lang in Locale.preferredLanguages { k.insert(String(lang.prefix(2))) }
        self.keep = k
    }

    public func scan() -> [LanguageFile] {
        var out: [LanguageFile] = []
        for dir in appDirs {
            guard let apps = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for app in apps where app.pathExtension == "app" {
                let res = app.appendingPathComponent("Contents/Resources")
                guard let entries = try? fileManager.contentsOfDirectory(at: res, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                for lproj in entries where lproj.pathExtension == "lproj" {
                    let lang = lproj.deletingPathExtension().lastPathComponent
                    guard !keep.contains(lang), !keep.contains(String(lang.prefix(2))) else { continue }
                    let size = scanner.size(of: lproj)
                    guard size > 0 else { continue }
                    out.append(LanguageFile(appName: app.deletingPathExtension().lastPathComponent,
                                            language: lang, url: lproj, sizeBytes: size))
                }
            }
        }
        return out.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
