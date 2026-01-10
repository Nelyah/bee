import Foundation
import OSLog

// MARK: - Project Display Info

/// Lightweight struct for project display attributes (emoji, color).
/// Used by TaskRow to display project info without loading full ProjectNode tree.
struct ProjectDisplayInfo: Equatable {
    let emoji: String?
    let color: String?
}

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
    /// Project currently being edited for emoji/color.
    var editingProjectPath: String?
    /// Whether an update is in progress.
    var isUpdating: Bool = false
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
    /// Pushes project overview onto the navigation stack for back navigation.
    func navigateToProjectOverview() {
        logger.info("Navigating to project overview")
        pushProjectOverview()
    }

    /// Exit the project overview and return to the previous view.
    /// Delegates to navigateBack() to pop from the navigation stack.
    func exitProjectOverview() {
        logger.info("Exiting project overview")
        // Reset burndown state but keep projects cached
        projectOverviewState.burndownState = .idle
        projectOverviewState.selectedProject = nil
        _ = navigateBack()
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
        // Reset navigation and go to list
        projectOverviewState.burndownState = .idle
        projectOverviewState.selectedProject = nil
        navigateToRoot()
        // Reload tasks with the new filter (same pattern as setProjectScope)
        handleInputChange(input)
    }

    /// Check if a project is expanded.
    func isProjectExpanded(_ projectPath: String) -> Bool {
        projectOverviewState.expandedProjects.contains(projectPath)
    }

    // MARK: - Project Editing

    /// Start editing a project's emoji/color.
    func startEditingProject(_ projectPath: String) {
        projectOverviewState.editingProjectPath = projectPath
    }

    /// Stop editing the current project.
    func stopEditingProject() {
        projectOverviewState.editingProjectPath = nil
    }

    /// Update a project's emoji.
    ///
    /// - Parameters:
    ///   - projectPath: The full path of the project (e.g., "backend.api").
    ///   - emoji: The new emoji string, or `nil` to clear the emoji.
    func updateProjectEmoji(_ projectPath: String, emoji: String?) async {
        guard !projectOverviewState.isUpdating else { return }

        projectOverviewState.isUpdating = true

        do {
            // Use .some(emoji) to set, .some(nil) to clear
            let emojiValue: String?? = .some(emoji)
            let response = try await apiClient.updateProject(
                project: projectPath,
                emoji: emojiValue,
                color: nil // Don't change color
            )
            updateProjectNodeInTree(projectPath, emoji: response.emoji, color: nil)
            logger.info("Updated emoji for '\(projectPath)' to '\(response.emoji ?? "none")'")
        } catch {
            showToast(message: "Failed to update emoji: \(error.localizedDescription)", icon: .warning)
            logger.error("Failed to update emoji for '\(projectPath)': \(error.localizedDescription)")
        }

        projectOverviewState.isUpdating = false
    }

    /// Update a project's color.
    ///
    /// - Parameters:
    ///   - projectPath: The full path of the project (e.g., "backend.api").
    ///   - color: The new hex color string (e.g., "#FF5733"), or `nil` to clear.
    func updateProjectColor(_ projectPath: String, color: String?) async {
        guard !projectOverviewState.isUpdating else { return }

        projectOverviewState.isUpdating = true

        do {
            // Use .some(color) to set, .some(nil) to clear
            let colorValue: String?? = .some(color)
            let response = try await apiClient.updateProject(
                project: projectPath,
                emoji: nil, // Don't change emoji
                color: colorValue
            )
            updateProjectNodeInTree(projectPath, emoji: nil, color: response.color)
            logger.info("Updated color for '\(projectPath)' to '\(response.color ?? "none")'")
        } catch {
            showToast(message: "Failed to update color: \(error.localizedDescription)", icon: .warning)
            logger.error("Failed to update color for '\(projectPath)': \(error.localizedDescription)")
        }

        projectOverviewState.isUpdating = false
    }

    /// Clear a project's emoji.
    func clearProjectEmoji(_ projectPath: String) async {
        await updateProjectEmoji(projectPath, emoji: nil)
    }

    /// Clear a project's color.
    func clearProjectColor(_ projectPath: String) async {
        await updateProjectColor(projectPath, color: nil)
    }

    // MARK: - Tree Updates

    /// Update a project node in the tree with new emoji/color values.
    ///
    /// - Parameters:
    ///   - projectPath: The full path of the project to update.
    ///   - emoji: New emoji value, or `nil` to leave unchanged.
    ///   - color: New color value, or `nil` to leave unchanged.
    private func updateProjectNodeInTree(_ projectPath: String, emoji: String??, color: String??) {
        projectOverviewState.projects = updateNodesRecursively(
            projectOverviewState.projects,
            targetPath: projectPath,
            emoji: emoji,
            color: color
        )
    }

    /// Recursively update nodes in the tree.
    private func updateNodesRecursively(
        _ nodes: [ProjectNode],
        targetPath: String,
        emoji: String??,
        color: String??
    ) -> [ProjectNode] {
        nodes.map { node in
            if node.fullPath == targetPath {
                // Found the target node, update it
                let newEmoji = emoji ?? node.emoji
                let newColor = color ?? node.color
                return ProjectNode(
                    name: node.name,
                    fullPath: node.fullPath,
                    emoji: newEmoji,
                    color: newColor,
                    stats: ProjectStats(
                        name: node.stats.name,
                        pendingCount: node.stats.pendingCount,
                        activeCount: node.stats.activeCount,
                        completedCount: node.stats.completedCount,
                        overdueCount: node.stats.overdueCount,
                        totalCount: node.stats.totalCount,
                        emoji: newEmoji,
                        color: newColor
                    ),
                    children: node.children
                )
            } else if !node.children.isEmpty {
                // Recurse into children
                return ProjectNode(
                    name: node.name,
                    fullPath: node.fullPath,
                    emoji: node.emoji,
                    color: node.color,
                    stats: node.stats,
                    children: updateNodesRecursively(node.children, targetPath: targetPath, emoji: emoji, color: color)
                )
            }
            return node
        }
    }

    // MARK: - Project Lookup

    /// Build a flat lookup dictionary from the project tree for O(1) access by path.
    /// Maps project fullPath → ProjectDisplayInfo (emoji, color).
    var projectDisplayLookup: [String: ProjectDisplayInfo] {
        var lookup: [String: ProjectDisplayInfo] = [:]
        flattenProjectTree(projectOverviewState.projects, into: &lookup)
        return lookup
    }

    /// Recursively flatten project tree into lookup dictionary.
    private func flattenProjectTree(_ nodes: [ProjectNode], into lookup: inout [String: ProjectDisplayInfo]) {
        for node in nodes {
            lookup[node.fullPath] = ProjectDisplayInfo(emoji: node.emoji, color: node.color)
            if !node.children.isEmpty {
                flattenProjectTree(node.children, into: &lookup)
            }
        }
    }
}
