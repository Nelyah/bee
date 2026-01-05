import SwiftUI

/// Main view for the project overview, showing a hierarchical list of projects with statistics.
struct ProjectOverviewView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ProjectOverviewHeader(onClose: viewModel.exitProjectOverview)

            Divider()
                .opacity(DesignTokens.Border.separatorOpacity)

            // Content
            if viewModel.projectOverviewState.isLoading {
                loadingView
            } else if let error = viewModel.projectOverviewState.errorMessage {
                errorView(error)
            } else if viewModel.projectOverviewState.projects.isEmpty {
                emptyView
            } else {
                projectListView
            }
        }
        .background(ThemeManager.current.surface0)
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading projects...")
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(ThemeManager.current.red)
            Text("Failed to load projects")
                .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold))
                .foregroundColor(ThemeManager.current.text)
            Text(message)
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.subtext0)
            Button("Retry") {
                Task {
                    await viewModel.loadProjectOverview()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundColor(ThemeManager.current.subtext0)
            Text("No projects found")
                .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold))
                .foregroundColor(ThemeManager.current.text)
            Text("Create tasks with projects to see them here")
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Project hierarchy
                ForEach(viewModel.projectOverviewState.projects) { project in
                    ProjectNodeView(
                        node: project,
                        indentLevel: 0,
                        viewModel: viewModel
                    )
                }

                // Burndown chart section
                burndownSection
                    .padding(.top, DesignTokens.Spacing.large)
            }
            .padding(DesignTokens.Spacing.large)
        }
    }

    @ViewBuilder
    private var burndownSection: some View {
        switch viewModel.projectOverviewState.burndownState {
        case .idle:
            EmptyView()
        case .loading:
            HStack {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Loading burndown...")
                    .font(.system(size: DesignTokens.TypeScale.body))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(DesignTokens.Spacing.medium)
        case let .loaded(response):
            BurndownChartView(data: response)
        case let .error(message):
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(ThemeManager.current.red)
                Text("Burndown error: \(message)")
                    .font(.system(size: DesignTokens.TypeScale.body))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(DesignTokens.Spacing.medium)
        }
    }
}

// MARK: - Header

struct ProjectOverviewHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: DesignTokens.IconSize.standard))
                .foregroundColor(ThemeManager.current.blue)

            Text("Projects Overview")
                .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold))
                .foregroundColor(ThemeManager.current.text)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: DesignTokens.IconSize.small))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
        .padding(.vertical, DesignTokens.Spacing.medium)
    }
}

// MARK: - Project Node View (Recursive)

struct ProjectNodeView: View {
    let node: ProjectNode
    let indentLevel: Int
    @ObservedObject var viewModel: LauncherViewModel

    private var isExpanded: Bool {
        viewModel.isProjectExpanded(node.fullPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row for this node
            ProjectStatsRow(
                node: node,
                isExpanded: isExpanded,
                indentLevel: indentLevel,
                onToggleExpand: {
                    viewModel.toggleProjectExpansion(node.fullPath)
                },
                onSelect: {
                    viewModel.selectProjectForFilter(node.fullPath)
                },
                onShowBurndown: {
                    Task {
                        await viewModel.loadBurndown(for: node.fullPath)
                    }
                }
            )

            // Children (if expanded)
            if isExpanded {
                ForEach(node.children) { child in
                    ProjectNodeView(
                        node: child,
                        indentLevel: indentLevel + 1,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectOverviewView(viewModel: LauncherViewModel(apiClient: MockApiClient()))
        .frame(width: 600, height: 400)
}
