import Foundation
import CoreGraphics
import ImageIO

/// Gruppo di immagini visivamente simili (non necessariamente identiche).
public struct SimilarPhotoGroup: Identifiable, Sendable {
    public let id = UUID()
    public var photos: [ScannedFile]
    public var reclaimableBytes: Int64 {
        let sorted = photos.sorted { $0.sizeBytes > $1.sizeBytes }
        return sorted.dropFirst().reduce(0) { $0 + $1.sizeBytes }
    }
}

/// Trova **foto simili** con un hash percettivo (average hash 8×8). Raggruppa immagini
/// vicine per distanza di Hamming. Sola lettura; rimozione poi via Cestino.
public struct PhotoScanner {
    private let fileManager: FileManager
    private let roots: [URL]
    private let exts: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "bmp"]

    public init(fileManager: FileManager = .default, home: URL? = nil, roots: [URL]? = nil) {
        self.fileManager = fileManager
        let h = home ?? fileManager.homeDirectoryForCurrentUser
        self.roots = roots ?? ["Pictures", "Downloads", "Desktop"].map { h.appendingPathComponent($0, isDirectory: true) }
    }

    public func scan(maxFiles: Int = 4000, threshold: Int = 6) -> [SimilarPhotoGroup] {
        var hashes: [(file: ScannedFile, hash: UInt64)] = []
        for url in imageFiles().prefix(maxFiles) {
            guard let h = averageHash(url) else { continue }
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let mod = (attrs?[.modificationDate] as? Date) ?? .distantPast
            hashes.append((ScannedFile(url: url, sizeBytes: size, modified: mod), h))
        }

        // Clustering semplice: unisci le immagini entro la soglia di Hamming.
        var used = Array(repeating: false, count: hashes.count)
        var groups: [SimilarPhotoGroup] = []
        for i in hashes.indices where !used[i] {
            var cluster = [hashes[i].file]
            used[i] = true
            for j in (i+1)..<hashes.count where !used[j] {
                if hamming(hashes[i].hash, hashes[j].hash) <= threshold {
                    cluster.append(hashes[j].file); used[j] = true
                }
            }
            if cluster.count > 1 {
                var sorted = cluster.sorted { $0.sizeBytes > $1.sizeBytes }
                for k in sorted.indices { sorted[k].isSelected = k > 0 }  // tieni la più grande
                groups.append(SimilarPhotoGroup(photos: sorted))
            }
        }
        return groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    // MARK: - Helper

    private func imageFiles() -> [URL] {
        var out: [URL] = []
        for root in roots {
            guard let en = fileManager.enumerator(at: root, includingPropertiesForKeys: nil,
                                                  options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                                  errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in en where exts.contains(url.pathExtension.lowercased()) {
                out.append(url)
            }
        }
        return out
    }

    /// Average hash: ridimensiona a 8×8 grayscale, confronta ogni pixel con la media.
    private func averageHash(_ url: URL) -> UInt64? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 8,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }

        let w = 8, h = 8
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(thumb, in: CGRect(x: 0, y: 0, width: w, height: h))

        let avg = pixels.reduce(0) { $0 + Int($1) } / pixels.count
        var hash: UInt64 = 0
        for (i, p) in pixels.enumerated() where Int(p) >= avg {
            hash |= (1 << UInt64(i))
        }
        return hash
    }

    private func hamming(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }
}
