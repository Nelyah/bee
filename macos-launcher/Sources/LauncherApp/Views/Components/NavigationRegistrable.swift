import SwiftUI

/// ViewModifier that registers a view as a navigation target.
///
/// Apply this modifier to focusable components to make them part of the
/// coordinate-based navigation system. The modifier captures the view's
/// frame in the "detailNavigation" coordinate space and reports it via
/// `NavigationCoordinatePreferenceKey`.
///
/// Usage:
/// ```swift
/// TagPill(tag: tag, ...)
///     .navigationRegistrable(.tag(tag, index: index))
/// ```
struct NavigationRegistrable: ViewModifier {
    /// The focusable item this view represents.
    let item: DetailFocusableItem

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: NavigationCoordinatePreferenceKey.self,
                            value: [NavigationCoordinateEntry(
                                item: item,
                                frame: geometry.frame(in: .named("detailNavigation"))
                            )]
                        )
                }
            )
            // Add stable ID for ScrollViewReader support
            .id(item.id)
    }
}

extension View {
    /// Registers this view as navigable with the given focusable item.
    ///
    /// The view's frame in the "detailNavigation" coordinate space will be
    /// tracked for coordinate-based hjkl navigation.
    ///
    /// - Parameter item: The `DetailFocusableItem` this view represents
    /// - Returns: A view that participates in navigation
    func navigationRegistrable(_ item: DetailFocusableItem) -> some View {
        modifier(NavigationRegistrable(item: item))
    }
}
