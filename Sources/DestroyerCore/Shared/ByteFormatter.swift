import Foundation

/// Formattazione dimensioni leggibili (es. "12,3 MB").
public enum ByteSize {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    public static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}
