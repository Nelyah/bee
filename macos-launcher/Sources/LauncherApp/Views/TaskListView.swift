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
    static let scrollAnimationDuration: Double = 0.12
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
                        isFocused: true,
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
                                viewModel.closeDetail()
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
                                .stroke(ThemeManager.current.surface1.opacity(TaskListLayout.strokeOpacity), lineWidth: 1)
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

                // Task list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: TaskListLayout.listSpacing) {
                            ForEach(Array(viewModel.tasks.enumerated()), id: \.offset) { index, task in
                                TaskRow(
                                    task: task,
                                    columns: viewModel.reportConfig?.columns ?? ["summary", "status"],
                                    isSelected: viewModel.selectedIndex == index
                                )
                                .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, TaskListLayout.listVerticalPadding)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newValue in
                        guard let index = newValue else { return }
                        withAnimation(.easeInOut(duration: TaskListLayout.scrollAnimationDuration)) {
                            proxy.scrollTo(index, anchor: .center)
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
