import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Search input field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CatppuccinTheme.subtext0)
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
                    .frame(height: 22)
                    .onChange(of: viewModel.input) { _, newValue in
                        viewModel.handleInputChange(newValue)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CatppuccinTheme.surface0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(CatppuccinTheme.surface1.opacity(0.5), lineWidth: 1)
                        )
                )

                // Column headers
                if let config = viewModel.reportConfig {
                    HStack(spacing: 12) {
                        // Status indicator column (fixed width)
                        Text("")
                            .frame(width: 8)

                        ForEach(Array(config.columnNames.enumerated()), id: \.offset) { index, name in
                            if index == 0 {
                                // First column after status (usually ID) - small fixed width
                                Text(name.uppercased())
                                    .frame(width: 30, alignment: .leading)
                            } else if config.columns[index] == "summary" {
                                // Summary column expands
                                Text(name.uppercased())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                // Other columns - auto width
                                Text(name.uppercased())
                                    .frame(width: 60, alignment: .leading)
                            }
                        }
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(CatppuccinTheme.subtext0)
                    .padding(.horizontal, 10)
                }

                // Task list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
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
                        .padding(.vertical, 4)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newValue in
                        guard let index = newValue else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }

                // Status message
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CatppuccinTheme.subtext1)
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
                .frame(width: 200)
                .offset(x: 34, y: 50)
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
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks
    viewModel.selectedIndex = 1
    viewModel.reportConfig = MockApiClient.sampleConfig.report

    return TaskListView(viewModel: viewModel)
        .padding(20)
        .frame(width: 600, height: 400)
        .background(CatppuccinTheme.base)
}
