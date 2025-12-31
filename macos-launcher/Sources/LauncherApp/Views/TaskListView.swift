import SwiftUI

fileprivate enum TaskListLayout {
    static let searchSpacing: CGFloat = DesignTokens.Spacing.md
    static let searchRowSpacing: CGFloat = DesignTokens.Spacing.md
    static let inputHeight: CGFloat = 30
    static let horizontalPadding: CGFloat = DesignTokens.Spacing.lg
    static let verticalPadding: CGFloat = DesignTokens.Spacing.md
    static let cornerRadius: CGFloat = DesignTokens.Radius.lg
    static let strokeOpacity: Double = 0.5
    static let criteriaTopPadding: CGFloat = DesignTokens.Spacing.xs
    static let criteriaBottomPadding: CGFloat = DesignTokens.Spacing.sm
    static let headerSpacing: CGFloat = DesignTokens.Spacing.md
    static let statusColumnWidth: CGFloat = 8
    static let firstColumnWidth: CGFloat = 30
    static let otherColumnWidth: CGFloat = 60
    static let headerFontSize: CGFloat = DesignTokens.TypeScale.caption
    static let headerPaddingHorizontal: CGFloat = DesignTokens.Spacing.md
    static let listSpacing: CGFloat = DesignTokens.Spacing.sm
    static let listVerticalPadding: CGFloat = DesignTokens.Spacing.xs
    static let statusFontSize: CGFloat = DesignTokens.TypeScale.bodySm
    static let completionMenuWidth: CGFloat = 200
    static let completionMenuOffsetX: CGFloat = 34
    static let completionMenuOffsetY: CGFloat = 50
    static let previewPadding: CGFloat = DesignTokens.Spacing.xl
    static let previewWidth: CGFloat = 600
    static let previewHeight: CGFloat = 400
}

struct TaskListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var completion: CompletionCoordinator
    @State private var reportBadgeFlash = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Search input field + report badge
                HStack(spacing: TaskListLayout.searchRowSpacing) {
                    HStack(spacing: TaskListLayout.searchSpacing) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ThemeManager.current.subtext0)
                        ZStack(alignment: .leading) {
                            if viewModel.input.isEmpty {
                                Text("Search tasks…")
                                    .font(.system(size: DesignTokens.TypeScale.input, weight: .medium, design: .rounded))
                                    .foregroundColor(ThemeManager.current.overlay0)
                                    .padding(.leading, 2)
                            }
                            TokenHighlightTextView(
                                text: $viewModel.input,
                                tokens: viewModel.tokens,
                                actionName: viewModel.actionName,
                                isFocused: viewModel.isInsertMode && !viewModel.commandPalette.isPresented,
                                ghostText: completion.ghostText,
                                cursorPosition: completion.cursorPosition,
                                showCompletionMenu: completion.showMenu,
                                onSubmit: {
                                    viewModel.handleSubmit()
                                },
                                onEscape: {
                                    if completion.showMenu {
                                        viewModel.clearCompletions()
                                    } else {
                                        viewModel.isInsertMode = false
                                    }
                                },
                                onMoveSelection: { delta in
                                    viewModel.moveSelection(delta: delta)
                                },
                                onCursorChange: { position in
                                    viewModel.handleCursorChange(position)
                                },
                                onToggleMenu: {
                                    viewModel.toggleCompletionMenu()
                                },
                                onAcceptGhost: {
                                    viewModel.acceptGhostText()
                                },
                                onMenuNavigation: { delta in
                                    viewModel.moveCompletionSelection(delta: delta)
                                },
                                onAcceptCompletion: {
                                    viewModel.acceptCompletion()
                                },
                                onRequestFocus: {
                                    guard !viewModel.commandPalette.isPresented else { return false }
                                    viewModel.enterInsertMode()
                                    return true
                                }
                            )
                        }
                        .frame(height: TaskListLayout.inputHeight)
                        .onChange(of: viewModel.input) { _, newValue in
                            viewModel.handleInputChange(newValue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, TaskListLayout.horizontalPadding)
                    .padding(.vertical, TaskListLayout.verticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: TaskListLayout.cornerRadius, style: .continuous)
                            .fill(ThemeManager.current.base)
                            .overlay(
                                RoundedRectangle(cornerRadius: TaskListLayout.cornerRadius, style: .continuous)
                                    .stroke(
                                        viewModel.isInsertMode
                                            ? ThemeManager.current.blue
                                            : ThemeManager.current.surface1.opacity(TaskListLayout.strokeOpacity),
                                        lineWidth: viewModel.isInsertMode ? 2 : 1
                                    )
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.enterInsertMode() }

                    if !viewModel.availableReports.isEmpty {
                        ReportMenuButton(
                            name: viewModel.currentReportDisplayName,
                            reports: viewModel.availableReports,
                            flash: $reportBadgeFlash
                        ) { name in
                            viewModel.selectReport(name)
                        }
                    }
                }

                CriteriaStripView(
                    filterChips: viewModel.criteriaFilterChips,
                    propertyChips: viewModel.criteriaPropertyChips
                )
                .padding(.horizontal, TaskListLayout.headerPaddingHorizontal)
                .padding(.top, TaskListLayout.criteriaTopPadding)
                .padding(.bottom, TaskListLayout.criteriaBottomPadding)

                // Column headers
                if let config = viewModel.reportConfig {
                    HStack(spacing: TaskListLayout.headerSpacing) {
                        // Status indicator column (fixed width)
                        Text("")
                            .frame(width: TaskListLayout.statusColumnWidth)

                        ForEach(Array(config.columnNames.enumerated()), id: \.offset) { index, name in
                            if index == 0 {
                                // First column after status (usually ID) - small fixed width
                                Text(name.uppercased())
                                    .frame(width: TaskListLayout.firstColumnWidth, alignment: .leading)
                            } else if config.columns[index] == "summary" {
                                // Summary column expands
                                Text(name.uppercased())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                // Other columns - auto width
                                Text(name.uppercased())
                                    .frame(width: TaskListLayout.otherColumnWidth, alignment: .leading)
                            }
                        }
                    }
                    .font(.system(size: TaskListLayout.headerFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .padding(.horizontal, TaskListLayout.headerPaddingHorizontal)
                }

                // Task list (grouped by project)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: TaskListLayout.listSpacing) {
                            ForEach(Array(viewModel.groupedRows.enumerated()), id: \.element.id) { rowIndex, row in
                                switch row {
                                case .header(let header):
                                    GroupHeaderRow(
                                        header: header,
                                        isHovered: viewModel.hoveredRowIndex == rowIndex,
                                        isSelected: viewModel.selectedRowIndex == rowIndex
                                    )
                                    .id(row.id)
                                    .onHover { hovering in
                                        viewModel.hoveredRowIndex = hovering ? rowIndex : nil
                                    }
                                    .onTapGesture { viewModel.activatePrimary(at: rowIndex) }

                                case .task(let item):
                                    TaskRow(
                                        task: item.task,
                                        columns: viewModel.reportConfig?.columns ?? ["summary", "status"],
                                        isSelected: viewModel.selectedRowIndex == rowIndex,
                                        isHovered: viewModel.hoveredRowIndex == rowIndex
                                    )
                                    .id(row.id)
                                    .onHover { hovering in
                                        viewModel.hoveredRowIndex = hovering ? rowIndex : nil
                                    }
                                    .onTapGesture { viewModel.selectRow(rowIndex) }
                                    .simultaneousGesture(
                                        TapGesture(count: 2).onEnded {
                                            viewModel.activatePrimary(at: rowIndex)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, TaskListLayout.listVerticalPadding)
                    }
                    .onChange(of: viewModel.selectedRowIndex) { _, newValue in
                        guard let index = newValue,
                              index < viewModel.groupedRows.count else { return }
                        let rowId = viewModel.groupedRows[index].id
                        proxy.scrollTo(rowId, anchor: nil)
                    }
                }

                // Status message
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.system(size: TaskListLayout.statusFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if completion.showMenu && !completion.items.isEmpty {
                    CompletionMenuView(
                        items: completion.items,
                        selectedIndex: completion.selectedIndex,
                        onSelect: { item in
                            viewModel.acceptCompletion(item)
                        }
                    )
                .frame(width: TaskListLayout.completionMenuWidth)
                .offset(x: TaskListLayout.completionMenuOffsetX, y: TaskListLayout.completionMenuOffsetY)
                .zIndex(1)
            }
        }
        .onAppear {
            Task {
                viewModel.loadCollapsedState()
                await viewModel.loadConfig()
                await viewModel.loadCompletionData()
                viewModel.loadInitialListIfNeeded()
            }
        }
    }
}


#Preview {
    let viewModel = makePreviewViewModel()
    TaskListView(viewModel: viewModel, completion: viewModel.completion)
        .padding(TaskListLayout.previewPadding)
        .frame(width: TaskListLayout.previewWidth, height: TaskListLayout.previewHeight)
        .background(ThemeManager.current.base)
}

@MainActor
private func makePreviewViewModel() -> LauncherViewModel {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks
    viewModel.selectedIndex = 1
    viewModel.reportConfig = MockApiClient.sampleConfig.report
    return viewModel
}
