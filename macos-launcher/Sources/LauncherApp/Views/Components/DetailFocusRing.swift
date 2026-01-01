import SwiftUI

/// A view modifier that adds a focus ring overlay to indicate keyboard focus.
struct DetailFocusRing: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    .stroke(
                        ThemeManager.current.blue.opacity(isFocused ? 1.0 : 0.0),
                        lineWidth: 2
                    )
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
            )
    }
}

extension View {
    /// Adds a focus ring overlay that becomes visible when focused.
    func detailFocusRing(isFocused: Bool) -> some View {
        modifier(DetailFocusRing(isFocused: isFocused))
    }
}
