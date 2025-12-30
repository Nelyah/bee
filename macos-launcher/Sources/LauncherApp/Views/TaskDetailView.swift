import SwiftUI

struct TaskDetailView: View {
    let task: ApiTask
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text(task.summary)
                    .font(.system(size: DesignTokens.TypeScale.title, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .lineLimit(2)
                Spacer()
                Text(task.status.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(ThemeManager.current.surface1)
                    )
            }

            DetailRow(label: "UUID", value: shortUUID(task.uuid), helpText: task.uuid)
            DetailRow(label: "Project", value: task.project ?? "None", helpText: nil)
            DetailRow(label: "Tags", value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "), helpText: nil)

            let created = formattedDate(task.dateCreated)
            DetailRow(label: "Created", value: created.display, helpText: created.help)

            let completed = formattedOptionalDate(task.dateCompleted, emptyLabel: "Not completed")
            DetailRow(label: "Completed", value: completed.display, helpText: completed.help)

            let due = formattedOptionalDate(task.dateDue, emptyLabel: "Not set")
            DetailRow(label: "Due", value: due.display, helpText: due.help)

            DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None", helpText: nil)

            Spacer()

            Text("Press Esc to go back")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .onExitCommand {
            onClose()
        }
    }

    private func shortUUID(_ value: String) -> String {
        let prefix = value.prefix(8)
        return "\(prefix)…"
    }

    private func formattedDate(_ value: String) -> (display: String, help: String?) {
        let display = RelativeDateFormatter.description(for: value)
        return (display, value)
    }

    private func formattedOptionalDate(_ value: String?, emptyLabel: String) -> (display: String, help: String?) {
        guard let value else {
            return (emptyLabel, nil)
        }
        return formattedDate(value)
    }
}

#Preview {
    TaskDetailView(task: MockApiClient.sampleTasks[0], onClose: {})
        .padding(24)
        .frame(width: 600, height: 400)
        .background(ThemeManager.current.base)
}
