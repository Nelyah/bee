import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @FocusState private var isSearchFocused: Bool

    private var actions: [CommandPaletteAction] {
        viewModel.filteredCommandPaletteActions
    }

    private var suggestions: [CommandPaletteSuggestion] {
        viewModel.filteredCommandPaletteSuggestions
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeCommandPalette()
                }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ThemeManager.current.subtext0)
                    TextField("Search", text: $viewModel.commandPaletteQuery)
                        .textFieldStyle(.plain)
                        .foregroundColor(ThemeManager.current.text)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.submitCommandPaletteSelection()
                        }
                }
                .padding(12)
                .background(ThemeManager.current.surface0)

                Divider()
                    .overlay(ThemeManager.current.surface1.opacity(0.6))

                contentList
            }
            .frame(width: 520)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ThemeManager.current.base)
                    .shadow(color: ThemeManager.current.surface2.opacity(0.4), radius: 18, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
            )
        }
        .onAppear {
            isSearchFocused = true
            if viewModel.commandPaletteMode != .root {
                viewModel.loadCommandPaletteSuggestions()
            }
        }
        .onChange(of: viewModel.commandPaletteQuery) { _, _ in
            viewModel.commandPaletteSelectionIndex = 0
        }
        .onExitCommand {
            viewModel.closeCommandPalette()
        }
        .onMoveCommand { direction in
            let maxCount = viewModel.commandPaletteMode == .root ? actions.count : suggestions.count
            switch direction {
            case .down:
                viewModel.moveCommandPaletteSelection(delta: 1, maxCount: maxCount)
            case .up:
                viewModel.moveCommandPaletteSelection(delta: -1, maxCount: maxCount)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var contentList: some View {
        if viewModel.commandPaletteIsLoading {
            VStack {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading…")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(24)
        } else if viewModel.commandPaletteMode == .root {
            listView(items: actions) { index, action in
                let isSelected = index == viewModel.commandPaletteSelectionIndex
                return Button {
                    viewModel.selectCommandPaletteAction(action)
                } label: {
                    HStack {
                        Text(action.rawValue)
                            .foregroundColor(ThemeManager.current.text)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectionBackground(isSelected: isSelected))
                }
                .buttonStyle(.plain)
            }
        } else {
            listView(items: suggestions) { index, item in
                let isSelected = index == viewModel.commandPaletteSelectionIndex
                return Button {
                    viewModel.commandPaletteSelectionIndex = index
                    viewModel.submitCommandPaletteSelection()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .foregroundColor(ThemeManager.current.text)
                        Text(item.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectionBackground(isSelected: isSelected))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? ThemeManager.current.surface1 : ThemeManager.current.base)
    }

    private func listView<Item: Identifiable, Row: View>(
        items: [Item],
        row: @escaping (Int, Item) -> Row
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(index, item)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 300)
    }
}

#Preview {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.isCommandPalettePresented = true
    viewModel.commandPaletteMode = .root
    return CommandPaletteView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}
