import SwiftUI

private enum TaskListLayout {
    static let searchSpacing: CGFloat = DesignTokens.Spacing.medium
    static let searchRowSpacing: CGFloat = DesignTokens.Spacing.medium
    static let inputHeight: CGFloat = 30
    static let horizontalPadding: CGFloat = DesignTokens.Spacing.large
    static let verticalPadding: CGFloat = DesignTokens.Spacing.medium
    static let cornerRadius: CGFloat = DesignTokens.Radius.large
    static let criteriaTopPadding: CGFloat = DesignTokens.Spacing.extraSmall
    static let criteriaBottomPadding: CGFloat = DesignTokens.Spacing.small
    static let headerSpacing: CGFloat = DesignTokens.Spacing.medium
    static let statusIndicatorWidth: CGFloat = DesignTokens.IconSize.statusIndicator
    static let firstColumnWidth: CGFloat = 30
    static let otherColumnWidth: CGFloat = 60
    static let statusColumnWidth: CGFloat = 80
    static let tagsColumnWidth: CGFloat = 80
    static let headerFontSize: CGFloat = DesignTokens.TypeScale.label
    static let headerLetterSpacing: CGFloat = 1.5
    static let headerPaddingHorizontal: CGFloat = DesignTokens.Spacing.medium
    static let listSpacing: CGFloat = DesignTokens.Spacing.small
    static let listVerticalPadding: CGFloat = DesignTokens.Spacing.extraSmall
    static let statusFontSize: CGFloat = DesignTokens.TypeScale.bodySm
    static let completionMenuWidth: CGFloat = 200
    static let completionMenuOffsetX: CGFloat = 34
    static let completionMenuOffsetY: CGFloat = 50
    static let previewPadding: CGFloat = DesignTokens.Spacing.extraLarge
    static let previewWidth: CGFloat = 600
    static let previewHeight: CGFloat = 400
}

struct TaskListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var completion: CompletionCoordinator
    @State private var reportBadgeFlash = false

    /// Whether any filters are currently active (search input, filter chips, or project scope)
    private var hasActiveFilters: Bool {
        !viewModel.criteriaFilterChips.isEmpty
            || !viewModel.criteriaPropertyChips.isEmpty
            || viewModel.projectScope != nil
            || !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Search input field + report badge
                HStack(spacing: TaskListLayout.searchRowSpacing) {
                    HStack(spacing: TaskListLayout.searchSpacing) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(
                                viewModel.isInsertMode
                                    ? ThemeManager.current.text
                                    : ThemeManager.current.subtext0
                            )
                            .animation(.easeInOut(duration: 0.15), value: viewModel.isInsertMode)
                        ZStack(alignment: .leading) {
                            if viewModel.input.isEmpty {
                                Text("Search tasks…")
                                    .font(.system(
                                        size: DesignTokens.TypeScale.input,
                                        weight: .medium,
                                        design: .rounded
                                    ))
                                    .foregroundColor(ThemeManager.current.subtext0)
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
                                            : ThemeManager.current.surface1
                                            .opacity(DesignTokens.Border.separatorOpacity),
                                        lineWidth: viewModel.isInsertMode ? 2 : 1
                                    )
                            )
                    )
                    .scaleEffect(viewModel.isInsertMode ? 1.01 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isInsertMode)
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

                    if let project = viewModel.projectScope {
                        ProjectScopeChipView(project: project) {
                            viewModel.clearProjectScope()
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
                if !viewModel.columnConfigs.isEmpty {
                    ColumnHeaderRow(
                        columnConfigs: viewModel.columnConfigs,
                        sortState: viewModel.sortState,
                        onSort: { column in
                            viewModel.toggleSort(for: column)
                        },
                        onResize: { column, delta in
                            viewModel.resizeColumn(column, delta: delta)
                        },
                        onResizeEnd: { column in
                            viewModel.finishResizing(column)
                        },
                        onReorder: { column, targetIndex in
                            viewModel.reorderColumn(column, to: targetIndex)
                        }
                    )

                    // Subtle divider below headers
                    Divider()
                        .background(ThemeManager.current.surface1.opacity(DesignTokens.Border.separatorOpacity))
                        .padding(.horizontal, TaskListLayout.headerPaddingHorizontal)
                }

                // Task list (grouped by project) or empty state
                if viewModel.groupedRows.isEmpty {
                    EmptyStateView(hasActiveFilters: hasActiveFilters)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: TaskListLayout.listSpacing) {
                                ForEach(Array(viewModel.groupedRows.enumerated()), id: \.element.id) { rowIndex, row in
                                    switch row {
                                    case let .header(header):
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

                                    case let .task(item):
                                        TaskRow(
                                            task: item.task,
                                            columnConfigs: viewModel.columnConfigs,
                                            isSelected: viewModel.selectedRowIndex == rowIndex,
                                            isHovered: viewModel.hoveredRowIndex == rowIndex,
                                            isExpanded: viewModel.isTaskExpanded(item.task.uuid),
                                            expandedContent: viewModel.taskExpandedData[item.task.uuid],
                                            onChevronTap: { viewModel.toggleTaskExpansion(item.task.uuid) }
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
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.expandedTasks)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            // Reserve space for BottomHintBar overlay so scrollTo respects it
                            Color.clear.frame(height: BottomHintBar.height + DesignTokens.Spacing.large)
                        }
                        .onChange(of: viewModel.selectedRowIndex) { _, newValue in
                            guard let index = newValue,
                                  index < viewModel.groupedRows.count else { return }
                            let rowId = viewModel.groupedRows[index].id
                            // anchor: nil only scrolls if item is out of visible area
                            proxy.scrollTo(rowId, anchor: nil)
                        }
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

            if completion.showMenu, !completion.items.isEmpty {
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
