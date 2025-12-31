import SwiftUI

/// A sheet for saving the current filter configuration as a named report.
///
/// Provides:
/// - Report name input with validation
/// - Preview of current filters
/// - Column customization (uses current report's columns)
/// - Confirmation for overwriting existing user reports
struct SaveReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @State private var reportName: String = ""
    @State private var validationError: String?
    @State private var showOverwriteConfirmation: Bool = false

    /// Current filter JSON from parse API.
    let currentFilter: JSONValue?
    /// Filter chip labels for display.
    let filterChipLabels: [String]
    /// Current columns configuration.
    let currentColumns: [String]
    /// Current column display names.
    let currentColumnNames: [String]
    /// Names of static reports (from bee.toml) - cannot be overwritten.
    let staticReportNames: Set<String>
    /// Names of existing user reports - can be overwritten with confirmation.
    let existingUserReportNames: Set<String>
    /// Callback when save is confirmed.
    let onSave: (String, JSONValue?, [String], [String]) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            // Title
            Text("Save Report")
                .font(.system(size: DesignTokens.TypeScale.title, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Form content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                // Report name field
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                    Text("Report Name")
                        .font(.system(size: DesignTokens.TypeScale.label))
                        .foregroundColor(.secondary)

                    TextField("my-report", text: $reportName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: DesignTokens.TypeScale.body))
                        .onChange(of: reportName) { _, _ in
                            validationError = nil
                        }

                    if let error = validationError {
                        Text(error)
                            .font(.system(size: DesignTokens.TypeScale.caption))
                            .foregroundColor(.red)
                    }
                }

                Divider()

                // Filters preview
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                    Text("Filters")
                        .font(.system(size: DesignTokens.TypeScale.label))
                        .foregroundColor(.secondary)

                    if filterChipLabels.isEmpty {
                        Text("No filters")
                            .font(.system(size: DesignTokens.TypeScale.bodySm))
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(filterChipLabels.joined(separator: " • "))
                            .font(.system(size: DesignTokens.TypeScale.bodySm))
                            .foregroundColor(.primary)
                    }
                }

                // Columns preview
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                    Text("Columns")
                        .font(.system(size: DesignTokens.TypeScale.label))
                        .foregroundColor(.secondary)

                    Text(currentColumnNames.joined(separator: ", "))
                        .font(.system(size: DesignTokens.TypeScale.bodySm))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Save") {
                    validateAndSave()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(reportName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.Spacing.extraLarge)
        .frame(width: 400, height: 340)
        .alert("Overwrite Report?", isPresented: $showOverwriteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Overwrite", role: .destructive) {
                performSave()
            }
        } message: {
            Text("A user report named '\(reportName)' already exists. Do you want to overwrite it?")
        }
    }

    private func validateAndSave() {
        let trimmedName = reportName.trimmingCharacters(in: .whitespaces)

        // Validate not empty
        guard !trimmedName.isEmpty else {
            validationError = "Report name cannot be empty"
            return
        }

        // Validate length
        guard trimmedName.count <= 64 else {
            validationError = "Report name must be 64 characters or less"
            return
        }

        // Only reject control characters - allow any printable Unicode
        guard !trimmedName.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            validationError = "Name cannot contain control characters"
            return
        }

        // Check collision with static reports
        if staticReportNames.contains(trimmedName) {
            validationError = "'\(trimmedName)' is a built-in report and cannot be overwritten"
            return
        }

        // Check if overwriting existing user report
        if existingUserReportNames.contains(trimmedName) {
            showOverwriteConfirmation = true
            return
        }

        performSave()
    }

    private func performSave() {
        let trimmedName = reportName.trimmingCharacters(in: .whitespaces)
        onSave(trimmedName, currentFilter, currentColumns, currentColumnNames)
        isPresented = false
    }
}

#Preview {
    SaveReportSheet(
        isPresented: .constant(true),
        currentFilter: .object(["type": .string("StatusFilter"), "status": .string("pending")]),
        filterChipLabels: ["Status: Pending", "Project: bee"],
        currentColumns: ["id", "summary", "status"],
        currentColumnNames: ["ID", "Summary", "Status"],
        staticReportNames: ["default", "all"],
        existingUserReportNames: ["my-custom"],
        onSave: { name, filter, columns, _ in
            print("Saving: \(name), filter: \(String(describing: filter)), columns: \(columns)")
        }
    )
}
