import SwiftUI

struct TaskDetailView: View {
    let task: ApiTask
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(task.summary)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .lineLimit(2)
                Spacer()
                Text(task.status.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ThemeManager.current.surface0)
                    )
            }

            DetailRow(label: "UUID", value: task.uuid)
            DetailRow(label: "Project", value: task.project ?? "None")
            DetailRow(label: "Tags", value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "))
            DetailRow(label: "Created", value: task.dateCreated)
            DetailRow(label: "Completed", value: task.dateCompleted ?? "Not completed")
            DetailRow(label: "Due", value: task.dateDue ?? "Not set")
            DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None")

            Spacer()

            Text("Press Esc to go back")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .onExitCommand {
            onClose()
        }
    }
}

#Preview {
    TaskDetailView(task: MockApiClient.sampleTasks[0], onClose: {})
        .padding(24)
        .frame(width: 600, height: 400)
        .background(ThemeManager.current.base)
}
