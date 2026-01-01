import SwiftUI

/// Empty state view displayed when the task list has no items.
/// Shows contextual messaging based on whether filters are active.
struct EmptyStateView: View {
    let hasActiveFilters: Bool

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: hasActiveFilters ? "magnifyingglass" : "checkmark.circle")
                .font(.system(size: DesignTokens.TypeScale.display, weight: .light))
                .foregroundColor(ThemeManager.current.subtext0)

            Text(hasActiveFilters ? "No tasks match your filters" : "No tasks yet")
                .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext1)

            Text(hasActiveFilters ? "Try removing some filters" : "Press ⌘I to create your first task")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .regular, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.extraLarge)
    }
}
