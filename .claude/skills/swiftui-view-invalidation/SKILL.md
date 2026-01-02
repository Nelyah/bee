---
name: swiftui-view-invalidation
description: Fixes SwiftUI view invalidation bugs where @State changes don't trigger re-renders. Use when views show stale data despite correct state, especially with GeometryReader overlays, or when debugging "view not updating" issues. (project)
allowed-tools: Read, Edit, Glob, Grep
---

# SwiftUI View Invalidation Patterns

Fixes common SwiftUI bugs where `@State` or `@Published` changes don't trigger view re-renders, causing stale UI despite correct underlying data.

## The GeometryReader Stale View Bug

### Symptoms
- Logs show correct state values, but UI displays old data
- Issue occurs inside `GeometryReader` or `overlay` modifiers
- Parent view updates don't propagate to nested views

### Root Cause (ELI5)

**Imagine SwiftUI as a photographer with a photo album:**

1. **The Setup**: Your view (e.g., dropdown) lives inside a `GeometryReader` (a special frame that measures sizes). Think of GeometryReader as a fancy picture frame.

2. **The Problem**: When state changes, your code correctly updates the data. But GeometryReader is lazy - it says "I already have a photo of this view in my album, why take a new one?" So it keeps showing the OLD photo.

3. **The Technical Cause**: GeometryReader creates a "view identity boundary" that prevents SwiftUI's normal state-change detection from triggering re-renders of its children.

### The Fix: `.id()` Modifier

Force SwiftUI to treat the view as a NEW instance when data changes:

```swift
// BEFORE (broken): View doesn't update when fuzzyMatches changes
.overlay(alignment: .topLeading) {
    GeometryReader { proxy in
        if !fuzzyMatches.isEmpty {
            CompletionMenuView(matches: fuzzyMatches, ...)
                .frame(...)
        }
    }
}

// AFTER (fixed): .id() forces re-render when fuzzyMatches changes
.overlay(alignment: .topLeading) {
    GeometryReader { proxy in
        if !fuzzyMatches.isEmpty {
            CompletionMenuView(matches: fuzzyMatches, ...)
                .id(fuzzyMatches.map { "\($0.item.id)" }.joined(separator: ","))
                .frame(...)
        }
    }
}
```

The `.id()` modifier is like writing a label on the photo. When the label changes, SwiftUI says "This is a DIFFERENT view - I need to rebuild it!"

### ID Strategies

| Data Type | ID Expression |
|-----------|---------------|
| Array of Identifiable | `.id(items.map { "\($0.id)" }.joined(separator: ","))` |
| Simple count change | `.id(items.count)` |
| Single value | `.id(selectedItem?.id)` |
| Multiple factors | `.id("\(count)-\(selectedId ?? "")")` |

## The "Publishing Changes" Warning

### Symptom
```
Publishing changes from within view updates is not allowed, this will cause undefined behavior.
```

### Root Cause

A `@Binding` connected to a `@Published` property updates during SwiftUI's view rendering cycle:

```
TextField → $text (@Binding)
         → viewModel.input (@Published) ← WARNING: triggers during render
```

### The Fix: Local State Buffer

Decouple immediate UI updates from `@Published` property updates:

```swift
// BEFORE (broken): Direct binding to @Published
@Binding var text: String  // Connected to viewModel.input
TextField(placeholder, text: $text)

// AFTER (fixed): Local buffer with deferred sync
@Binding var text: String
@State private var localText: String = ""

TextField(placeholder, text: $localText)
    .onAppear { localText = text }
    .onChange(of: localText) { _, newValue in
        // Update local state immediately (fast, no warning)
        doSomethingWith(newValue)

        // Defer binding update to avoid warning
        DispatchQueue.main.async {
            text = newValue
        }
    }
```

## Quick Diagnostic Checklist

When a view shows stale data:

1. **Add debug logging** to confirm state IS being set correctly
2. **Check for GeometryReader** - is the stale view inside one?
3. **Check for overlays** - same issue can occur in `.overlay()` or `.background()`
4. **Look for @Published warnings** in console
5. **Try `.id()` modifier** as first fix attempt

## Guardrails

### Always Do
- Use `.id()` when views inside GeometryReader depend on changing state
- Use local state buffers when TextField binds to @Published properties
- Add debug logging before assuming "SwiftUI is broken"

### Ask First
- Before adding `.id()` to performance-critical views (can cause animation issues)
- Before restructuring view hierarchy as alternative fix

### Never Do
- Ignore "Publishing changes from within view updates" warnings
- Assume state isn't being set because UI looks wrong (add logging first)
