import SwiftUI

/// An editable date row that displays a date and allows editing
/// via a popover with a DatePicker and quick action buttons.
///
/// Follows the same two-state pattern as `EditableProjectRow`:
/// - Display mode: Shows the formatted date with a focus ring when keyboard-focused
/// - Edit mode: Shows a popover with DatePicker and quick actions
///
/// Can be used for both due dates and planned dates by setting the `label` parameter.
struct EditableDueDateRow: View {
    /// The label to display (e.g., "DUE" or "PLANNED").
    let label: String

    /// The current date as an ISO8601 string, or nil if not set.
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

    @State private var isHovering = false

    var body: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }

    private func deferAction(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }

    // MARK: - Display Mode

    private var displayView: some View {
        let formatted = formattedDueDate
        return HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            Text(label)
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)

            Text(formatted.display)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
                .help(formatted.help ?? formatted.display)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
                    .frame(
                        width: geo.size.width + 2 * DesignTokens.Spacing.small,
                        height: geo.size.height + 2 * DesignTokens.Spacing.extraSmall
                    )
                    .offset(
                        x: -DesignTokens.Spacing.small,
                        y: -DesignTokens.Spacing.extraSmall
                    )
            }
        )
        .modifier(DetailFocusRing(isFocused: isFocused))
        .contentShape(Rectangle())
        .onTapGesture {
            onStartEditing()
        }
        .onHover { isHovering = $0 }
        .help(isFocused ? "Press Enter to edit" : "Click to edit")
    }

    /// Formats the due date for display using specific rules:
    /// - Today: "today at 13:00"
    /// - Tomorrow: "tomorrow at 09:00"
    /// - Within 7 days: "Wednesday at 14:30"
    /// - Within 3 months: "January 24 at 13:00"
    /// - Beyond 3 months: "January 24, 2027 at 13:00"
    private var formattedDueDate: (display: String, help: String?) {
        guard let dateString = currentDueDate,
              let date = RelativeDateFormatter.date(from: dateString)
        else {
            return ("—", nil)
        }

        let calendar = Calendar.current
        let now = Date()

        // Format time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)

        // Calculate days difference from start of day
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let daysDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfDate).day ?? 0

        let dateDisplay: String
        if daysDiff == 0 {
            dateDisplay = "today"
        } else if daysDiff == 1 {
            dateDisplay = "tomorrow"
        } else if daysDiff > 1, daysDiff < 7 {
            // Weekday name (Wednesday, Thursday, etc.)
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            dateDisplay = weekdayFormatter.string(from: date)
        } else {
            // Check if within 3 months
            let monthsDiff = calendar.dateComponents([.month], from: now, to: date).month ?? 0
            let dateFormatter = DateFormatter()
            if abs(monthsDiff) < 3 {
                dateFormatter.dateFormat = "MMMM d" // "January 24"
            } else {
                dateFormatter.dateFormat = "MMMM d, yyyy" // "January 24, 2027"
            }
            dateDisplay = dateFormatter.string(from: date)
        }

        return ("\(dateDisplay) at \(timeString)", dateString)
    }

    // MARK: - Editing Mode

    private var editingView: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text(label.capitalized)
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
                        deferAction(onCancel)
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

            // Calendar picker using AppKit's NSDatePicker for proper sizing
            // Native size ~260x290, scaled 1.8x = ~468x522, minimal padding
            LargeCalendarPicker(selection: $selectedDate)

            Divider()

            // Time preset buttons
            timePresetsRow

            Divider()

            // Time input - digital style with manual entry
            HStack {
                Text("Time:")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)

                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.stepperField)
                .labelsHidden()

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.small)

            Divider()

            actionButtonsRow
        }
        .padding(DesignTokens.Spacing.medium)
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

    /// Row of time preset buttons for common times.
    private var timePresetsRow: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            timePresetButton("Morning", hour: 9)
            timePresetButton("Noon", hour: 12)
            timePresetButton("EOD", hour: 17)
            timePresetButton("Evening", hour: 20)
        }
    }

    /// A single time preset button that sets the hour.
    private func timePresetButton(_ label: String, hour: Int) -> some View {
        Button(label) {
            var components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: selectedDate
            )
            components.hour = hour
            components.minute = 0
            if let newDate = Calendar.current.date(from: components) {
                selectedDate = newDate
            }
        }
        .buttonStyle(.bordered)
        .font(.system(size: DesignTokens.TypeScale.bodySm))
        .controlSize(.small)
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
                    label: "DUE",
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
                    label: "DUE",
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
                    label: "DUE",
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
