import Foundation

// MARK: - Reports & Filter Chips

extension LauncherViewModel {
    /// Display name for the current report.
    var currentReportDisplayName: String {
        if selectedReportName.isEmpty {
            return availableReports.first(where: { $0.isDefault })?.name ?? "default"
        }
        return selectedReportName
    }

    /// Filter chips from the currently selected report (displayed with muted styling).
    var criteriaReportFilterChips: [CriteriaChip] {
        reportFilterChips
    }

    /// Filter chips added manually by the user via input (displayed with vibrant styling).
    var criteriaManualFilterChips: [CriteriaChip] {
        guard let parsed = lastSuccessfulParse else { return [] }
        let parsedChips = CriteriaChipBuilder.filterChips(from: parsed.filter, source: .manual)
        if parsedChips.isEmpty, shouldAutoList(actionName: parsed.action) {
            return CriteriaChipBuilder.filterChips(
                from: parsed.tokens,
                actionName: parsed.action
            )
        }
        return parsedChips
    }

    /// All filter chips combined (for backward compatibility).
    var criteriaFilterChips: [CriteriaChip] {
        deduplicateChips(reportFilterChips + criteriaManualFilterChips)
    }

    var criteriaPropertyChips: [CriteriaChip] {
        guard let parsed = lastSuccessfulParse else { return [] }
        return CriteriaChipBuilder.propertyChips(from: parsed.properties)
    }

    /// Chip representing the current project scope, if any.
    var projectScopeChip: CriteriaChip? {
        guard let project = projectScope else { return nil }
        return CriteriaChip(kind: .filter, label: project, systemImage: "folder", tone: .teal)
    }

    func refreshReportFilterChips() async {
        guard let reportConfig else {
            reportFilterChips = []
            return
        }

        let reportName = currentReportDisplayName

        // User reports have pre-parsed filter JSON - use it directly
        if let userFilter = reportConfig.userFilter {
            let chips = CriteriaChipBuilder.filterChips(
                from: userFilter,
                source: .report,
                reportName: reportName
            )
            reportFilterChips = deduplicateChips(chips)
            return
        }

        // Static reports have filter expression strings - need to parse them
        let filterExpr = reportConfig.staticFilters.joined(separator: " or ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filterExpr.isEmpty else {
            reportFilterChips = []
            return
        }

        do {
            let parsed = try await actionService.parse(input: "list \(filterExpr)")
            let parsedChips = CriteriaChipBuilder.filterChips(
                from: parsed.filter,
                source: .report,
                reportName: reportName
            )
            let fallbackChips = CriteriaChipBuilder.filterChips(from: parsed.tokens, actionName: parsed.action)
            // Add source to fallback chips
            let fallbackWithSource = fallbackChips.map { chip in
                CriteriaChip(
                    kind: chip.kind,
                    source: .report,
                    label: chip.label,
                    systemImage: chip.systemImage,
                    tone: chip.tone,
                    reportName: reportName
                )
            }
            reportFilterChips = deduplicateChips(parsedChips.isEmpty ? fallbackWithSource : parsedChips)
        } catch {
            logger.error("Failed to parse report filters: \(error.localizedDescription, privacy: .public)")
            reportFilterChips = CriteriaChipBuilder.reportFilterChips(
                from: reportConfig,
                reportName: reportName
            )
        }
    }

    func deduplicateChips(_ chips: [CriteriaChip]) -> [CriteriaChip] {
        var seen = Set<String>()
        var result: [CriteriaChip] = []
        for chip in chips where seen.insert(chip.id).inserted {
            result.append(chip)
        }
        return result
    }

    /// Select a report by name and refresh the task list.
    func selectReport(_ name: String) {
        guard let report = availableReports.first(where: { $0.name == name }) else { return }
        selectedReportName = name
        settingsService.selectedReportName = name
        reportConfig = ReportConfig(
            staticFilters: report.staticFilters,
            userFilter: report.userFilter,
            columns: report.columns,
            columnNames: report.columnNames
        )
        actionService.setReportConfig(reportConfig)
        Task {
            await refreshReportFilterChips()
        }
        // Refresh task list with new report filters
        handleInputChange(input)
    }

    /// Switch to the "all" report (no filters). Called when user removes a report filter chip.
    func switchToAllReport() {
        // Find the "all" report or first available report without filters
        let allReport = availableReports.first(where: { $0.name.lowercased() == "all" })
            ?? availableReports.first(where: { $0.staticFilters.isEmpty && $0.userFilter == nil })
        if let report = allReport {
            selectReport(report.name)
        } else {
            // Fallback: clear report filters but keep current report structure
            reportFilterChips = []
            handleInputChange(input)
        }
    }
}
