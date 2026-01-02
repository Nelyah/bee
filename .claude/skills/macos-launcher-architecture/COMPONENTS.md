# Reusable Components

**Read this when:** Creating or modifying reusable UI components.

## Component Location

```
Views/Components/
├── Buttons/
│   ├── ActionButton.swift
│   ├── IconButton.swift
│   └── TagButton.swift
├── Badges/
│   ├── StatusBadge.swift
│   └── TagBadge.swift
├── Cards/
│   └── TaskCard.swift
├── Inputs/
│   ├── SearchField.swift
│   └── TokenInput.swift
├── Tooltips/
│   └── TooltipView.swift
├── ExternalLinkRow/
│   └── ExternalLinkRow.swift
└── TokenHighlight/
    └── TokenHighlightTextView.swift
```

## Component Guidelines

### 1. Self-Contained

Components should be independent and reusable:

```swift
// Good: All dependencies passed in
struct StatusBadge: View {
    let status: TaskStatus
    let theme: Theme

    var body: some View {
        Text(status.displayName)
            .foregroundColor(theme.statusColor(for: status))
    }
}

// Bad: Reaches into global state
struct StatusBadge: View {
    let status: TaskStatus
    @EnvironmentObject var themeManager: ThemeManager  // Avoid
}
```

### 2. Configurable

Use parameters for customization:

```swift
struct IconButton: View {
    let icon: String
    let action: () -> Void

    // Optional customization with defaults
    var size: CGFloat = 20
    var color: Color = .primary
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(isEnabled ? color : .gray)
        }
        .disabled(!isEnabled)
    }
}
```

### 3. Documented

Add documentation for public interface:

```swift
/// A badge displaying a task's current status with appropriate coloring.
///
/// - Parameters:
///   - status: The task status to display
///   - theme: Theme providing status colors
///   - size: Badge size (default: .regular)
struct StatusBadge: View {
    // ...
}
```

## Common Patterns

### DetailSection Styling Convention

`DetailSection` uppercases titles automatically. When creating custom sections (e.g., collapsible variants), match this pattern:

```swift
// DetailSection does this internally:
Text(title.uppercased())
    .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
    .foregroundColor(ThemeManager.current.subtext0)

// Custom sections must match:
Text("HISTORY")  // Already uppercased
    .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
    .foregroundColor(ThemeManager.current.subtext0)
```

Also apply the container styling (padding, background, border) to match `DetailSection`.

### Hover + Focus ButtonStyle

Combine hover and focus states in custom button styles:

```swift
private struct CopyableDetailRowButtonStyle: ButtonStyle {
    let isFocused: Bool
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(isFocused ? ThemeManager.current.blue : Color.clear, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
```

Key pattern: Background fill for hover, stroke overlay for focus, opacity for press.

### Button with State Feedback

```swift
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Text(title)
            }
        }
        .disabled(isLoading)
    }
}
```

### Chip/Tag Component

```swift
struct TagChip: View {
    let text: String
    let color: Color
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}
```

### Tooltip Component

```swift
struct TooltipView<Content: View>: View {
    let text: String
    let content: Content

    @State private var isHovering = false

    init(_ text: String, @ViewBuilder content: () -> Content) {
        self.text = text
        self.content = content()
    }

    var body: some View {
        content
            .onHover { hovering in
                isHovering = hovering
            }
            .overlay(alignment: .top) {
                if isHovering {
                    Text(text)
                        .font(.caption)
                        .padding(4)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .offset(y: -30)
                }
            }
    }
}

// Usage
TooltipView("Click to mark as done") {
    StatusBadge(status: .pending, theme: theme)
}
```

### Conditional Wrapper

```swift
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Usage
Text("Hello")
    .if(isHighlighted) { view in
        view.background(Color.yellow)
    }
```

## Creating a New Component

### Step 1: Create File

```
Views/Components/{Category}/{ComponentName}.swift
```

### Step 2: Implement Component

```swift
import SwiftUI

/// Brief description of component purpose.
struct MyComponent: View {
    // MARK: - Properties

    let requiredProp: String
    var optionalProp: Color = .primary

    // MARK: - Body

    var body: some View {
        // Implementation
    }
}

// MARK: - Preview

#Preview {
    MyComponent(requiredProp: "Preview")
}
```

### Step 3: Add Tests

**Behavior test:**
```swift
final class MyComponentUITests: XCTestCase {
    func testDisplaysContent() throws {
        let sut = MyComponent(requiredProp: "Test")
        let view = try sut.inspect()
        _ = try view.find(text: "Test")
    }
}
```

**Snapshot test:**
```swift
final class MyComponentSnapshotTests: SnapshotTestCase {
    func testDefaultAppearance() {
        let view = MyComponent(requiredProp: "Test")
        assertViewSnapshot(view, size: CGSize(width: 200, height: 50))
    }
}
```

## Design Tokens

Use design tokens for consistency:

```swift
struct MyComponent: View {
    var body: some View {
        HStack(spacing: DesignTokens.spacing.small) {
            // ...
        }
        .padding(DesignTokens.spacing.medium)
        .cornerRadius(DesignTokens.cornerRadius.small)
    }
}
```

Available tokens:
- `DesignTokens.spacing` - small, medium, large
- `DesignTokens.cornerRadius` - small, medium, large
- `DesignTokens.shadow` - subtle, medium, prominent

## Theming

Use Theme protocol for colors:

```swift
struct MyComponent: View {
    let theme: Theme

    var body: some View {
        Text("Hello")
            .foregroundColor(theme.textPrimary)
            .background(theme.backgroundSecondary)
    }
}
```

Theme properties:
- `textPrimary`, `textSecondary`, `textMuted`
- `backgroundPrimary`, `backgroundSecondary`
- `accent`, `border`, `divider`
- `statusColor(for: TaskStatus)`
