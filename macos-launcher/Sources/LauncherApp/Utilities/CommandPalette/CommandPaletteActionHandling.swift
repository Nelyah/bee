import Foundation

// MARK: - Action Handlers Protocol

/// Protocol for handling command palette actions.
///
/// Implementers provide handlers for building submenus and executing actions.
@MainActor
protocol CommandPaletteActionHandling {
    /// Builds a submenu for selecting reports
    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu

    /// Builds a submenu for adding GitLab links
    func buildGitlabMenu(taskUUID: String) -> CommandPaletteMenu

    /// Builds a submenu for adding Jira links
    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu

    /// Clears the current project scope
    func clearProjectScope()

    /// Builds a submenu for selecting link type (blocks, depends on, etc.)
    func buildLinkTypeMenu(taskUUID: String) -> CommandPaletteMenu

    /// Builds a submenu for selecting target task
    func buildTaskSelectorMenu(linkType: LinkType, sourceTaskUUID: String) -> CommandPaletteMenu

    /// Shows the save report sheet
    func showSaveReportSheet()

    /// Deletes a user report
    func deleteUserReport(name: String)

    /// Opens file picker to add an attachment to the current task
    func addAttachment()
}
