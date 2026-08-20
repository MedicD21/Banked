import SwiftUI

/// Central design tokens for the app's dark, modern visual style. The app
/// forces dark mode (see `ThemedRoot`), so these are plain `Color` values
/// rather than asset-catalog colors with light/dark variants.
enum Theme {

    enum Colors {
        static let canvas = Color(red: 0.035, green: 0.043, blue: 0.055)
        static let surface = Color(red: 0.075, green: 0.090, blue: 0.110)
        static let surfaceElevated = Color(red: 0.106, green: 0.125, blue: 0.149)
        static let divider = Color.white.opacity(0.08)

        static let accent = Color(red: 0.204, green: 0.784, blue: 0.529)
        static let accentBright = Color(red: 0.369, green: 0.922, blue: 0.659)

        static let positive = Color(red: 0.298, green: 0.784, blue: 0.510)
        static let negative = Color(red: 0.937, green: 0.400, blue: 0.400)
        static let warning = Color(red: 0.937, green: 0.729, blue: 0.353)

        static let textPrimary = Color.white.opacity(0.95)
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary = Color.white.opacity(0.35)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
    }
}

/// Applies the app-wide dark appearance, accent tint, and list/nav-bar
/// backgrounds. Wrapped around `RootView` so every screen inherits it.
struct ThemedRoot: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Theme.Colors.accent)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func themedRoot() -> some View {
        modifier(ThemedRoot())
    }

    /// Standard themed background for a `NavigationStack` + `List` screen.
    func themedScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.canvas)
    }
}

/// Card-style container used for grouping content outside of a `List`
/// (e.g. the category editor form, empty states).
struct ThemedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            content
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

/// A pill-shaped status badge (linked-institution status, etc).
struct ThemedBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}
