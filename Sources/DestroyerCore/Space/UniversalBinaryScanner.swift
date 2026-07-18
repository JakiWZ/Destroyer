import Foundation

/// Un eseguibile "universale" (fat) che contiene più architetture (es. Intel + Apple Silicon).
public struct FatBinary: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let appName: String
    public let url: URL
    public let sizeBytes: Int64
    public let archs: [String]
    public var isSelected: Bool

    public init(appName: String, url: URL, sizeBytes: Int64, archs: [String], isSelected: Bool = false) {
        self.appName = appName; self.url = url; self.sizeBytes = sizeBytes
        self.archs = archs; self.isSelected = isSelected
    }
}

/// Individua i binari universali nelle app e permette di "assottigliarli" (`lipo -thin`)
/// mantenendo solo l'architettura nativa.
/// ATTENZIONE: l'operazione è **IRREVERSIBILE** e **invalida la firma** dell'app
/// (potrebbe non avviarsi più con Gatekeeper). Usare con consapevolezza.
public struct UniversalBinaryScanner {
    private let fileManager: FileManager
    private let appDirs: [URL]

    public init(fileManager: FileManager = .default, appDirs: [URL]? = nil) {
        self.fileManager = fileManager
        self.appDirs = appDirs ?? [URL(fileURLWithPath: "/Applications"),
                                   fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    }

    /// Architettura nativa della macchina.
    public var nativeArch: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    public func scan() -> [FatBinary] {
        var out: [FatBinary] = []
        for dir in appDirs {
            guard let apps = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for app in apps where app.pathExtension == "app" {
                guard let exe = mainExecutable(app) else { continue }
                let archs = architectures(of: exe)
                guard archs.count > 1 else { continue }
                let attrs = try? fileManager.attributesOfItem(atPath: exe.path)
                let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                out.append(FatBinary(appName: app.deletingPathExtension().lastPathComponent,
                                     url: exe, sizeBytes: size, archs: archs))
            }
        }
        return out.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Assottiglia i binari selezionati mantenendo solo l'architettura nativa. IRREVERSIBILE.
    /// Ritorna quanti assottigliati con successo.
    @discardableResult
    public func thin(_ urls: [URL]) -> Int {
        var done = 0
        for url in urls {
            let tmp = url.deletingLastPathComponent().appendingPathComponent(".dz-thin-\(UUID().uuidString)")
            if run(["/usr/bin/lipo", url.path, "-thin", nativeArch, "-output", tmp.path]) == 0 {
                if (try? fileManager.removeItem(at: url)) != nil,
                   (try? fileManager.moveItem(at: tmp, to: url)) != nil {
                    done += 1
                } else {
                    try? fileManager.removeItem(at: tmp)
                }
            } else {
                try? fileManager.removeItem(at: tmp)
            }
        }
        return done
    }

    // MARK: - Helper

    private func mainExecutable(_ bundle: URL) -> URL? {
        let infoURL = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let exe = info["CFBundleExecutable"] as? String else { return nil }
        let url = bundle.appendingPathComponent("Contents/MacOS/\(exe)")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func architectures(of exe: URL) -> [String] {
        let out = runCapture(["/usr/bin/lipo", "-archs", exe.path])
        return out.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init).filter { !$0.isEmpty }
    }

    private func run(_ argv: [String]) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit(); return p.terminationStatus
    }

    private func runCapture(_ argv: [String]) -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: argv[0]); p.arguments = Array(argv.dropFirst())
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
