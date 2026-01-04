import SwiftUI

/// An editable due date row that displays the current due date and allows editing
/// via a popover with a DatePicker and quick action buttons.
///
/// Follows the same two-state pattern as `EditableProjectRow`:
/// - Display mode: Shows the formatted date with a focus ring when keyboard-focused
/// - Edit mode: Shows a popover with DatePicker and quick actions
struct EditableDueDateRow: View {
    /// The current due date as an ISO8601 string, or nil if not set.
    let currentDueDate: String?

    /// Whether the date picker popover is being shown.
    let isEditing: Bool

    /// The date currently selected in the picker.
    @Binding var selectedDate: Date

    /// Whether a due date submission is in progress.
    let isSubmitting: Bool

    /// Whether this row has keyboard focus (shows focus ring).
    let isFocused: Bool

    /// Called when the user clicks/taps the row to start editing.
    let onStartEditing: () -> Void

    /// Called when the user saves the selected date.
    let onSubmit: () -> Void

    /// Called when the user cancels editing.
    let onCancel: () -> Void

    /// Called when the user clears the due date.
    let onClear: () -> Void

    /// Called when the user selects a quick date action.
    let onQuickAction: (QuickDueDateAction) -> Void

    var body: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }

    // MARK: - Display Mode

    private var displayView: some View {
        let formatted = formattedDueDate
        return DetailRow(label: "Due", value: formatted.display, helpText: formatted.help)
            .modifier(DetailFocusRing(isFocused: isFocused))
            .contentShape(Rectangle())
            .onTapGesture {
                onStartEditing()
            }
            .help(isFocused ? "Press Enter to edit" : "Click to edit")
    }

    /// Formats the due date for display using RelativeDateFormatter.
    private var formattedDueDate: (display: String, help: String?) {
        guard let dateString = currentDueDate else {
            return ("—", nil)
        }
        let display = RelativeDateFormatter.description(for: dateString)
        return (display, dateString)
    }

    // MARK: - Editing Mode

    private var editingView: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text("Due")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 80, alignment: .leading)

            datePickerAnchor
        }
    }

    /// The button that anchors the popover and shows the currently selected date.
    private var datePickerAnchor: some View {
        Button {
            // Button is just an anchor; popover is controlled by isEditing
        } label: {
            HStack(spacing: DesignTokens.Spacing.small) {
                Text(selectedDateDisplay)
                    .font(.system(size: DesignTokens.TypeScale.body))
                    .foregroundColor(ThemeManager.current.text)

                Image(systemName: "calendar")
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(ThemeManager.current.surface1)
            .cornerRadius(DesignTokens.Radius.small)
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: Binding(
                get: { isEditing },
                set: { newValue in
                    if !newValue {
                        onCancel()
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            datePickerPopover
        }
    }

    /// Formatted display of the selected date.
    private var selectedDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: selectedDate)
    }

    // MARK: - Date Picker Popover

    private var datePickerPopover: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            quickActionsRow

            Divider()

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            Divider()

            actionButtonsRow
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(minWidth: 320)
    }

    /// Row of quick action buttons for common dates.
    private var quickActionsRow: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach([QuickDueDateAction.today, .tomorrow, .nextWeekday], id: \.label) { action in
                    quickActionButton(action)
                }
            }
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach([QuickDueDateAction.nextWeek, .inOneWeek], id: \.label) { action in
                    quickActionButton(action)
                }
            }
        }
    }

    /// A single quick action button.
    private func quickActionButton(_ action: QuickDueDateAction) -> some View {
        Button(action.label) {
            onQuickAction(action)
        }
        .buttonStyle(.bordered)
        .font(.system(size: DesignTokens.TypeScale.bodySm))
        .controlSize(.small)
    }

    /// Row with Clear, Cancel, and Save buttons.
    private var actionButtonsRow: some View {
        HStack {
            if currentDueDate != nil {
                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.plain)
                .foregroundColor(ThemeManager.current.red)
                .font(.system(size: DesignTokens.TypeScale.bodySm))
            }

            Spacer()

            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .font(.system(size: DesignTokens.TypeScale.bodySm))

            Button("Save") {
                onSubmit()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .font(.system(size: DesignTokens.TypeScale.bodySm))
            .disabled(isSubmitting)
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct EditableDueDateRow_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                // Display mode - no due date
                EditableDueDateRow(
                    currentDueDate: nil,
                    isEditing: false,
                    selectedDate: .constant(Date()),
                    isSubmitting: false,
                    isFocused: false,
                    onStartEditing: {},
                    onSubmit: {},
                    onCancel: {},
                    onClear: {},
                    onQuickAction: { _ in }
                )

                // Display mode - with due date, focused
                EditableDueDateRow(
                    currentDueDate: "2025-01-15T09:00:00Z",
                    isEditing: false,
                    selectedDate: .constant(Date()),
                    isSubmitting: false,
                    isFocused: true,
                    onStartEditing: {},
                    onSubmit: {},
                    onCancel: {},
                    onClear: {},
                    onQuickAction: { _ in }
                )

                // Editing mode
                EditableDueDateRow(
                    currentDueDate: "2025-01-15T09:00:00Z",
                    isEditing: true,
                    selectedDate: .constant(Date()),
                    isSubmitting: false,
                    isFocused: false,
                    onStartEditing: {},
                    onSubmit: {},
                    onCancel: {},
                    onClear: {},
                    onQuickAction: { _ in }
                )
            }
            .padding()
            .frame(width: 400)
        }
    }
#endif
