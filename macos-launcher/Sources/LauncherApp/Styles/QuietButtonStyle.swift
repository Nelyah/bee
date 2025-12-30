import SwiftUI

/// A subtle button style with configurable press animation.
/// Use for interactive elements that should feel responsive but not distracting.
struct QuietButtonStyle: ButtonStyle {
    let isHovering: Bool
    var pressedOpacity: Double = 0.7
    var pressedScale: CGFloat = 0.98
    var animationDuration: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeOut(duration: animationDuration), value: configuration.isPressed)
            .animation(.easeOut(duration: animationDuration), value: isHovering)
    }
}
