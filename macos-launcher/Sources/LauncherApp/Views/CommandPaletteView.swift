import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var commandPaletteMonitor: Any?

    private var actions: [CommandPaletteAction] {
        viewModel.filteredCommandPaletteActions
    }

    private var suggestions: [CommandPaletteSuggestion] {
        viewModel.filteredCommandPaletteSuggestions
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeCommandPalette()
                }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    searchIcon
                        .foregroundColor(ThemeManager.current.subtext0)
                    TextField("Search", text: $viewModel.commandPaletteQuery)
                        .textFieldStyle(.plain)
                        .foregroundColor(ThemeManager.current.text)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.submitCommandPaletteSelection()
                        }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ThemeManager.current.surface0)
                )
                .padding(12)

                Divider()
                    .overlay(ThemeManager.current.surface1.opacity(0.6))

                contentList
            }
            .frame(width: 520)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ThemeManager.current.base)
                    .shadow(color: ThemeManager.current.surface2.opacity(0.4), radius: 18, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
            )
        }
        .onAppear {
            isSearchFocused = true
            if viewModel.commandPaletteMode != .root {
                viewModel.loadCommandPaletteSuggestions()
            }
            installCommandPaletteMonitor()
        }
        .onDisappear {
            removeCommandPaletteMonitor()
        }
        .onChange(of: viewModel.commandPaletteQuery) { _, _ in
            viewModel.commandPaletteSelectionIndex = 0
        }
        .onExitCommand {
            viewModel.closeCommandPalette()
        }
        .onMoveCommand { direction in
            let maxCount = viewModel.commandPaletteMode == .root ? actions.count : suggestions.count
            switch direction {
            case .down:
                viewModel.moveCommandPaletteSelection(delta: 1, maxCount: maxCount)
            case .up:
                viewModel.moveCommandPaletteSelection(delta: -1, maxCount: maxCount)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var contentList: some View {
        if viewModel.commandPaletteIsLoading {
            VStack {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading…")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(24)
        } else if viewModel.commandPaletteMode == .root {
            listView(items: actions) { index, action in
                let isSelected = index == viewModel.commandPaletteSelectionIndex
                return Button {
                    viewModel.selectCommandPaletteAction(action)
                } label: {
                    HStack {
                        Text(action.rawValue)
                            .foregroundColor(ThemeManager.current.text)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectionBackground(isSelected: isSelected))
                }
                .buttonStyle(.plain)
            }
        } else {
            listView(items: suggestions) { index, item in
                let isSelected = index == viewModel.commandPaletteSelectionIndex
                return Button {
                    viewModel.commandPaletteSelectionIndex = index
                    viewModel.submitCommandPaletteSelection()
                } label: {
                    switch item {
                    case .gitlab(let mr):
                        gitlabSuggestionRow(mr: mr, isSelected: isSelected)
                    case .jira:
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayTitle)
                                .foregroundColor(ThemeManager.current.text)
                            Text(item.subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectionBackground(isSelected: isSelected))
                    case .rawInput:
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayTitle)
                                .foregroundColor(ThemeManager.current.text)
                            Text(item.subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectionBackground(isSelected: isSelected))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var searchIcon: some View {
        if viewModel.commandPaletteMode == .addGitlab {
            if let icon = AssetIcon.gitlab() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "magnifyingglass")
                    .frame(width: 16, height: 16)
            }
        } else {
            Image(systemName: "magnifyingglass")
                .frame(width: 16, height: 16)
        }
    }

    private func gitlabSuggestionRow(mr: GitlabMergeRequestSuggestion, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(mrStateIconName(for: mr.state), bundle: .module)
                .resizable()
                .renderingMode(.original)
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(mr.title)
                        .foregroundColor(ThemeManager.current.text)
                    Spacer()
                    pipelineStatusView(status: mr.pipelineStatus)
                    approvalBadge(approved: mr.approved)
                }

                Text("MR !\(mr.id) • \(mr.projectPath)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)

                HStack(spacing: 12) {
                    if let notes = mr.notesCount {
                        Label("\(notes)", systemImage: "bubble.left")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                    Text(RelativeDateFormatter.description(for: mr.updatedAt))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext0)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground(isSelected: isSelected))
    }

    @ViewBuilder
    private func pipelineStatusView(status: String?) -> some View {
        if let status,
           let iconName = pipelineIconName(for: status) {
            HStack(spacing: 4) {
                Image(iconName, bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 12, height: 12)
                Text(pipelineStatusLabel(for: status))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
        }
    }

    private func approvalBadge(approved: Bool?) -> some View {
        let text: String
        let color: Color
        switch approved {
        case .some(true):
            text = "Approved"
            color = ThemeManager.current.green
        case .some(false):
            text = "Needs approval"
            color = ThemeManager.current.yellow
        case .none:
            text = "Approval unknown"
            color = ThemeManager.current.subtext0
        }

        return Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func mrStateIconName(for state: String) -> String {
        switch state.lowercased() {
        case "merged":
            return "pr-merged"
        case "closed":
            return "pr-closed"
        default:
            return "pr-open"
        }
    }

    private func pipelineIconName(for status: String) -> String? {
        switch status.lowercased() {
        case "success":
            return "gitlab-success"
        case "running":
            return "gitlab-running"
        case "pending", "failed", "canceled", "skipped":
            return "gitlab-pending"
        default:
            return nil
        }
    }

    private func pipelineStatusLabel(for status: String) -> String {
        switch status.lowercased() {
        case "success":
            return "Passed"
        case "failed":
            return "Failed"
        case "running":
            return "Running"
        case "pending":
            return "Pending"
        case "canceled":
            return "Canceled"
        case "skipped":
            return "Skipped"
        default:
            return status.capitalized
        }
    }

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? ThemeManager.current.surface1 : ThemeManager.current.base)
    }

    /// Capture Ctrl+N/P to move selection in the command palette.
    private func installCommandPaletteMonitor() {
        guard commandPaletteMonitor == nil else { return }
        commandPaletteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard viewModel.isCommandPalettePresented else { return event }
            guard event.modifierFlags.contains(.control) else { return event }
            let maxCount = viewModel.commandPaletteMode == .root
                ? viewModel.filteredCommandPaletteActions.count
                : viewModel.filteredCommandPaletteSuggestions.count
            switch event.keyCode {
            case KeyCode.n:
                viewModel.moveCommandPaletteSelection(delta: 1, maxCount: maxCount)
                return nil
            case KeyCode.p:
                viewModel.moveCommandPaletteSelection(delta: -1, maxCount: maxCount)
                return nil
            default:
                return event
            }
        }
    }

    /// Remove the command palette key monitor.
    private func removeCommandPaletteMonitor() {
        if let monitor = commandPaletteMonitor {
            NSEvent.removeMonitor(monitor)
            commandPaletteMonitor = nil
        }
    }

    private func listView<Item: Identifiable, Row: View>(
        items: [Item],
        row: @escaping (Int, Item) -> Row
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(index, item)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 300)
    }
}

#Preview {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.isCommandPalettePresented = true
    viewModel.commandPaletteMode = .root
    return CommandPaletteView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}
