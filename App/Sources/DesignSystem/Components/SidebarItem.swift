import SwiftUI

/// Riga della sidebar con pill selezionata luminosa e stato "in arrivo".
struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var isAvailable: Bool = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if !isAvailable {
                    Text("presto")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.strokeStrong))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accentSolid.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var iconColor: Color {
        if isSelected { return Theme.accentSolid }
        return isAvailable ? Theme.textSecondary : Theme.textTertiary
    }

    private var background: Color {
        if isSelected { return Theme.accentSolid.opacity(0.14) }
        return hovering ? Theme.surface : .clear
    }
}
