import SwiftUI

/// Treemap grafica: rettangoli proporzionali alla dimensione (split binario ricorsivo).
struct SpaceTreemap: View {
    let entries: [SpaceEntry]
    var onSelect: (SpaceEntry) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let items = Array(entries.prefix(24))
            let rects = layout(items, in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(items, rects)), id: \.0.id) { entry, rect in
                    tile(entry, rect: rect)
                }
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }

    private func tile(_ entry: SpaceEntry, rect: CGRect) -> some View {
        let total = max(1, entries.reduce(0) { $0 + $1.sizeBytes })
        let intensity = min(1.0, Double(entry.sizeBytes) / Double(total) * 4)
        return RoundedRectangle(cornerRadius: 4)
            .fill(Theme.accentSolid.opacity(0.25 + intensity * 0.6))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.background, lineWidth: 1.5))
            .overlay(alignment: .topLeading) {
                if rect.width > 54 && rect.height > 26 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).font(Theme.mono(9, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(ByteSize.string(entry.sizeBytes)).font(Theme.mono(8)).foregroundStyle(.white.opacity(0.8))
                    }.padding(4)
                }
            }
            .frame(width: max(1, rect.width), height: max(1, rect.height))
            .offset(x: rect.minX, y: rect.minY)
            .help("\(entry.name) — \(ByteSize.string(entry.sizeBytes))")
            .onTapGesture { onSelect(entry) }
    }

    /// Layout treemap con split binario proporzionale.
    private func layout(_ items: [SpaceEntry], in rect: CGRect) -> [CGRect] {
        guard items.count > 1 else { return items.isEmpty ? [] : [rect] }
        let total = items.reduce(0.0) { $0 + Double($1.sizeBytes) }
        var acc = 0.0, idx = 0
        for (i, e) in items.enumerated() {
            if acc + Double(e.sizeBytes) > total / 2, i > 0 { break }
            acc += Double(e.sizeBytes); idx = i + 1
        }
        idx = max(1, min(items.count - 1, idx))
        let first = Array(items[0..<idx]), second = Array(items[idx...])
        let firstFrac = CGFloat(first.reduce(0.0) { $0 + Double($1.sizeBytes) } / total)

        if rect.width >= rect.height {
            let w = rect.width * firstFrac
            return layout(first, in: CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height))
                 + layout(second, in: CGRect(x: rect.minX + w, y: rect.minY, width: rect.width - w, height: rect.height))
        } else {
            let h = rect.height * firstFrac
            return layout(first, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h))
                 + layout(second, in: CGRect(x: rect.minX, y: rect.minY + h, width: rect.width, height: rect.height - h))
        }
    }
}
