import SwiftUI

/// A button that tracks hover state and passes it to its label.
/// Eliminates the need for separate `@State var isHovering` + `.onHover` boilerplate.
struct HoverableButton<Label: View>: View {
    let action: () -> Void
    let label: (Bool) -> Label
    var pressedOpacity: Double = 0.7
    var pressedScale: CGFloat = 0.98
    var animationDuration: Double = 0.12

    @State private var isHovering = false

    init(
        action: @escaping () -> Void,
        pressedOpacity: Double = 0.7,
        pressedScale: CGFloat = 0.98,
        animationDuration: Double = 0.12,
        @ViewBuilder label: @escaping (Bool) -> Label
    ) {
        self.action = action
        self.pressedOpacity = pressedOpacity
        self.pressedScale = pressedScale
        self.animationDuration = animationDuration
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label(isHovering)
        }
        .buttonStyle(QuietButtonStyle(
            isHovering: isHovering,
            pressedOpacity: pressedOpacity,
            pressedScale: pressedScale,
            animationDuration: animationDuration
        ))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// A link-styled hoverable element (no button chrome, shows underline on hover).
struct HoverableLink<Label: View>: View {
    let label: (Bool) -> Label
    @State private var isHovering = false

    init(@ViewBuilder label: @escaping (Bool) -> Label) {
        self.label = label
    }

    var body: some View {
        label(isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
