import Foundation
import OSLog

// MARK: - Project Overview State

/// State for the project overview view.
struct ProjectOverviewState: Equatable {
    /// Whether project data is being loaded.
    var isLoading: Bool = false
    /// The hierarchical project tree.
    var projects: [ProjectNode] = []
    /// Error message if loading failed.
    var errorMessage: String?
    /// Set of expanded project paths (for tree view).
    var expandedProjects: Set<String> = []
    /// Currently selected project for burndown display.
    var selectedProject: String?
    /// State for burndown data loading.
    var burndownState: BurndownState = .idle
}

/// State for loading burndown data.
enum BurndownState: Equatable {
    case idle
    case loading
    case loaded(ProjectBurndownResponse)
    case error(String)
}

// MARK: - LauncherViewModel Extension

extension LauncherViewModel {
    // MARK: - Navigation

    /// Navigate to the project overview view.
    func navigateToProjectOverview() {
        logger.info("Navigating to project overview")
        mode = .projectOverview
        // Auto-load projects when entering the view
        Task {
            await loadProjectOverview()
        }
    }

    /// Exit the project overview and return to the task list.
    func exitProjectOverview() {
        logger.info("Exiting project overview")
        mode = .list
        // Reset burndown state but keep projects cached
        projectOverviewState.burndownState = .idle
        projectOverviewState.selectedProject = nil
    }

    // MARK: - Data Loading

    /// Load the project overview data from the API.
    func loadProjectOverview() async {
        guard !projectOverviewState.isLoading else { return }

        projectOverviewState.isLoading = true
        projectOverviewState.errorMessage = nil

        do {
            let response = try await apiClient.fetchProjects()
            projectOverviewState.projects = response.projects
            projectOverviewState.isLoading = false

            // Auto-expand top-level projects
            for project in response.projects where project.hasChildren {
                projectOverviewState.expandedProjects.insert(project.fullPath)
            }

            logger.info("Loaded \(response.projects.count) top-level projects")
        } catch {
            projectOverviewState.isLoading = false
            projectOverviewState.errorMessage = error.localizedDescription
            logger.error("Failed to load projects: \(error.localizedDescription)")
        }
    }

    /// Load burndown data for a specific project.
    func loadBurndown(for projectPath: String, days: Int = 30) async {
        projectOverviewState.selectedProject = projectPath
        projectOverviewState.burndownState = .loading

        do {
            let response = try await apiClient.fetchProjectBurndown(project: projectPath, days: days)
            projectOverviewState.burndownState = .loaded(response)
            logger.info("Loaded burndown for '\(projectPath)': \(response.dataPoints.count) data points")
        } catch {
            projectOverviewState.burndownState = .error(error.localizedDescription)
            logger.error("Failed to load burndown for '\(projectPath)': \(error.localizedDescription)")
        }
    }

    // MARK: - Tree Interaction

    /// Toggle expansion state for a project node.
    func toggleProjectExpansion(_ projectPath: String) {
        if projectOverviewState.expandedProjects.contains(projectPath) {
            projectOverviewState.expandedProjects.remove(projectPath)
        } else {
            projectOverviewState.expandedProjects.insert(projectPath)
        }
    }

    /// Select a project and apply it as a filter in the task list.
    func selectProjectForFilter(_ projectPath: String) {
        logger.info("Filtering by project: '\(projectPath)'")
        // Set the project scope and return to list view
        projectScope = projectPath
        mode = .list
        // Reload tasks with the new filter (same pattern as setProjectScope)
        handleInputChange(input)
    }

    /// Check if a project is expanded.
    func isProjectExpanded(_ projectPath: String) -> Bool {
        projectOverviewState.expandedProjects.contains(projectPath)
    }
}
