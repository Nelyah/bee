import SwiftUI

fileprivate enum TaskListLayout {
    static let searchSpacing: CGFloat = 10
    static let inputHeight: CGFloat = 22
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let strokeOpacity: Double = 0.5
    static let headerSpacing: CGFloat = 12
    static let statusColumnWidth: CGFloat = 8
    static let firstColumnWidth: CGFloat = 30
    static let otherColumnWidth: CGFloat = 60
    static let headerFontSize: CGFloat = 10
    static let headerPaddingHorizontal: CGFloat = 10
    static let listSpacing: CGFloat = 6
    static let listVerticalPadding: CGFloat = 4
    static let statusFontSize: CGFloat = 12
    static let completionMenuWidth: CGFloat = 200
    static let completionMenuOffsetX: CGFloat = 34
    static let completionMenuOffsetY: CGFloat = 50
    static let previewPadding: CGFloat = 20
    static let previewWidth: CGFloat = 600
    static let previewHeight: CGFloat = 400
}

struct TaskListView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Search input field
                HStack(spacing: TaskListLayout.searchSpacing) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ThemeManager.current.subtext0)
                    TokenHighlightTextView(
                        text: $viewModel.input,
                        tokens: viewModel.tokens,
                        actionName: viewModel.actionName,
                        isFocused: viewModel.isInsertMode,
                        ghostText: viewModel.ghostText,
                        cursorPosition: viewModel.cursorPosition,
                        showCompletionMenu: viewModel.showCompletionMenu,
                        onSubmit: {
                            viewModel.handleSubmit()
                        },
                        onEscape: {
                            if viewModel.showCompletionMenu {
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
                        }
                    )
                    .frame(height: TaskListLayout.inputHeight)
                    .onChange(of: viewModel.input) { _, newValue in
                        viewModel.handleInputChange(newValue)
                    }
                }
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
                                        isSelected: viewModel.selectedRowIndex == rowIndex,
                                        onToggle: { viewModel.toggleGroupCollapse(header.key) }
                                    )
                                    .id(row.id)
                                    .onHover { hovering in
                                        viewModel.hoveredRowIndex = hovering ? rowIndex : nil
                                    }

                                case .task(let item):
                                    TaskRow(
                                        task: item.task,
                                        columns: viewModel.reportConfig?.columns ?? ["summary", "status"],
                                        isSelected: viewModel.selectedRowIndex == rowIndex
                                    )
                                    .id(row.id)
                                    .onHover { hovering in
                                        viewModel.hoveredRowIndex = hovering ? rowIndex : nil
                                    }
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

            if viewModel.showCompletionMenu && !viewModel.completions.isEmpty {
                CompletionMenuView(
                    items: viewModel.completions,
                    selectedIndex: viewModel.selectedCompletionIndex,
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
    TaskListView(viewModel: makePreviewViewModel())
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
