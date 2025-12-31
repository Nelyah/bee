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

    var criteriaFilterChips: [CriteriaChip] {
        var chips = reportFilterChips
        if let parsed = lastSuccessfulParse {
            let parsedChips = CriteriaChipBuilder.filterChips(from: parsed.filter)
            if parsedChips.isEmpty, shouldAutoList(actionName: parsed.action) {
                chips.append(contentsOf: CriteriaChipBuilder.filterChips(
                    from: parsed.tokens,
                    actionName: parsed.action
                ))
            } else if !parsedChips.isEmpty {
                chips.append(contentsOf: parsedChips)
            }
        }
        return deduplicateChips(chips)
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
        let filterExpr = reportConfig.filters.joined(separator: " or ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filterExpr.isEmpty else {
            reportFilterChips = []
            return
        }

        do {
            let parsed = try await actionService.parse(input: "list \(filterExpr)")
            let parsedChips = CriteriaChipBuilder.filterChips(from: parsed.filter)
            let fallbackChips = CriteriaChipBuilder.filterChips(from: parsed.tokens, actionName: parsed.action)
            reportFilterChips = deduplicateChips(parsedChips.isEmpty ? fallbackChips : parsedChips)
        } catch {
            logger.error("Failed to parse report filters: \(error.localizedDescription, privacy: .public)")
            reportFilterChips = CriteriaChipBuilder.reportFilterChips(from: reportConfig)
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
        UserDefaults.standard.set(name, forKey: UserDefaultsKeys.selectedReportName)
        reportConfig = ReportConfig(
            filters: report.filters,
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
}
