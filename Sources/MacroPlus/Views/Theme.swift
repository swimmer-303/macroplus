import SwiftUI

/// Shared visual language for MacroPlus.
enum Theme {
    static let accent = Color(red: 0.40, green: 0.49, blue: 1.0)
    static let accent2 = Color(red: 0.66, green: 0.40, blue: 1.0)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}

/// Rounded card container used across panels.
struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title = title {
                Label {
                    Text(title).font(.headline)
                } icon: {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage).foregroundStyle(Theme.accent)
                    }
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Big primary action button with gradient fill.
struct PrimaryButton: View {
    var title: String
    var systemImage: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accentGradient))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
