import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var commandPalette: CommandPaletteCoordinator
    @FocusState private var isSearchFocused: Bool
    @State private var commandPaletteMonitor: Any?

    private var actions: [CommandPaletteAction] {
        commandPalette.filteredActions
    }

    private var suggestions: [CommandPaletteSuggestion] {
        commandPalette.filteredSuggestions
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeCommandPalette()
                }

            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    searchIcon
                        .foregroundColor(ThemeManager.current.subtext0)
                    TextField("Search", text: $commandPalette.query)
                        .textFieldStyle(.plain)
                        .foregroundColor(ThemeManager.current.text)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.submitCommandPaletteSelection()
                        }
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .fill(ThemeManager.current.surface0)
                )
                .padding(DesignTokens.Spacing.lg)

                Divider()
                    .overlay(ThemeManager.current.surface1.opacity(0.6))

                contentList
            }
            .frame(width: 520)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                    .fill(ThemeManager.current.base)
                    .shadow(color: ThemeManager.current.surface2.opacity(0.4), radius: 18, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                    .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
            )
        }
        .onAppear {
            isSearchFocused = true
            if commandPalette.mode != .root {
                viewModel.loadCommandPaletteSuggestions()
            }
            installCommandPaletteMonitor()
        }
        .onDisappear {
            removeCommandPaletteMonitor()
        }
        .onChange(of: commandPalette.query) { _, _ in
            commandPalette.resetSelection()
        }
        .onExitCommand {
            viewModel.closeCommandPalette()
        }
        .onMoveCommand { direction in
            let maxCount = commandPalette.mode == .root ? actions.count : suggestions.count
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
        if commandPalette.isLoading {
            VStack {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading…")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(DesignTokens.Spacing.xxl)
        } else if commandPalette.mode == .root {
            listView(items: actions) { index, action in
                let isSelected = index == commandPalette.selectionIndex
                return Button {
                    viewModel.selectCommandPaletteAction(action)
                } label: {
                    HStack {
                        Text(action.rawValue)
                            .foregroundColor(ThemeManager.current.text)
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectionBackground(isSelected: isSelected))
                }
                .buttonStyle(.plain)
            }
        } else {
            listView(items: suggestions) { index, item in
                let isSelected = index == commandPalette.selectionIndex
                return Button {
                    commandPalette.selectionIndex = index
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
                                .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectionBackground(isSelected: isSelected))
                    case .rawInput:
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayTitle)
                                .foregroundColor(ThemeManager.current.text)
                            Text(item.subtitle)
                                .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
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
        if commandPalette.mode == .addGitlab {
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
            Image(mr.state.iconName, bundle: .module)
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
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)

                HStack(spacing: 12) {
                    if let notes = mr.notesCount {
                        Label("\(notes)", systemImage: "bubble.left")
                            .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                    Text(RelativeDateFormatter.description(for: mr.updatedAt))
                        .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext0)
                    Spacer()
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground(isSelected: isSelected))
    }

    @ViewBuilder
    private func pipelineStatusView(status: GitlabPipelineStatus?) -> some View {
        if let status,
           let iconName = status.iconName {
            HStack(spacing: 4) {
                Image(iconName, bundle: .module)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 12, height: 12)
                Text(status.label)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
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
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
            .fill(isSelected ? ThemeManager.current.surface1 : ThemeManager.current.base)
    }

    /// Capture Ctrl+N/P to move selection in the command palette.
    private func installCommandPaletteMonitor() {
        guard commandPaletteMonitor == nil else { return }
        commandPaletteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard commandPalette.isPresented else { return event }
            guard event.modifierFlags.contains(.control) else { return event }
            let maxCount = commandPalette.mode == .root
                ? commandPalette.filteredActions.count
                : commandPalette.filteredSuggestions.count
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
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(maxHeight: 300)
    }
}

#Preview {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.commandPalette.isPresented = true
    viewModel.commandPalette.mode = .root
    return CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
        .frame(width: 680, height: 440)
}
