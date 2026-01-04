import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var commandPalette: CommandPaletteCoordinator
    @FocusState private var isSearchFocused: Bool
    @State private var commandPaletteMonitor: Any?

    // MARK: - Computed Properties

    private var sections: [CommandPaletteSection] {
        commandPalette.currentSections
    }

    private var selectableMatchedItems: [FuzzyMatchedPaletteItem] {
        commandPalette.selectableMatchedItems
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeCommandPalette()
                }

            VStack(spacing: 0) {
                // Breadcrumb bar when not at root
                if !commandPalette.isAtRoot {
                    breadcrumbBar
                }

                // Search header
                HStack(spacing: DesignTokens.Spacing.medium) {
                    Image(systemName: "magnifyingglass")
                        .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
                        .foregroundColor(ThemeManager.current.subtext0)
                    TextField("Search", text: $commandPalette.query)
                        .textFieldStyle(.plain)
                        .foregroundColor(ThemeManager.current.text)
                        .focused($isSearchFocused)
                        .onSubmit {
                            commandPalette.handleEnter()
                        }
                }
                .padding(DesignTokens.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                        .fill(ThemeManager.current.surface0)
                )
                .padding(DesignTokens.Spacing.large)

                Divider()
                    .overlay(ThemeManager.current.surface1.opacity(0.6))

                contentList
            }
            .frame(width: 520)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.extraLarge, style: .continuous)
                    .fill(ThemeManager.current.base)
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.extraLarge, style: .continuous)
                    .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
            )
        }
        .onAppear {
            installCommandPaletteMonitor()
            // Set focus on next run loop iteration, after AppKit's makeFirstResponder(nil)
            // has cleared focus from TokenHighlightTextView
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onDisappear {
            removeCommandPaletteMonitor()
        }
        .onChange(of: commandPalette.query) { _, _ in
            commandPalette.resetSelection()
        }
        .onExitCommand {
            if !commandPalette.handleEscape() {
                viewModel.closeCommandPalette()
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                commandPalette.moveSelection(delta: 1)
            case .up:
                commandPalette.moveSelection(delta: -1)
            default:
                break
            }
        }
    }

    // MARK: - Breadcrumb Bar

    @ViewBuilder
    private var breadcrumbBar: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Button {
                commandPalette.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .buttonStyle(.plain)

            Text(commandPalette.breadcrumb.joined(separator: " › "))
                .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(ThemeManager.current.surface0.opacity(0.5))
    }

    // MARK: - Content List

    @ViewBuilder
    private var contentList: some View {
        if commandPalette.isLoading {
            loadingView
        } else {
            sectionedContentList
        }
    }

    // MARK: - Sectioned Content List

    @ViewBuilder
    private var sectionedContentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Back row when not at root
                    if !commandPalette.isAtRoot {
                        backRow
                    }

                    // Sections
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(DesignTokens.Spacing.large)
            }
            .frame(maxHeight: 300)
            .onChange(of: commandPalette.selectionIndex) { _, newIndex in
                guard newIndex < selectableMatchedItems.count else { return }
                let itemId = selectableMatchedItems[newIndex].id
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(itemId, anchor: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: CommandPaletteSection) -> some View {
        // Section header with optional highlighting
        if let title = section.title {
            sectionHeader(title: title, match: section.sectionTitleMatch)
        }

        // Section items with match info for highlighting
        ForEach(section.matchedItems) { matchedItem in
            itemRow(matchedItem)
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, match: FuzzyMatch?) -> some View {
        let uppercasedTitle = title.uppercased()
        let headerFont = Font.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded)
        let baseColor = ThemeManager.current.subtext0
        let matchColor = ThemeManager.current.blue

        Group {
            if let match, !match.matchedIndices.isEmpty {
                // Highlight matched characters in section header
                FuzzyMatcher.highlightedText(
                    uppercasedTitle,
                    matchedIndices: match.matchedIndices,
                    baseFont: headerFont,
                    baseColor: baseColor,
                    matchColor: matchColor,
                    matchWeight: .bold
                )
            } else {
                Text(uppercasedTitle)
                    .font(headerFont)
                    .foregroundColor(baseColor)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
        .padding(.top, DesignTokens.Spacing.medium)
        .padding(.bottom, DesignTokens.Spacing.extraSmall)
    }

    @ViewBuilder
    private func itemRow(_ matchedItem: FuzzyMatchedPaletteItem) -> some View {
        let item = matchedItem.item
        if let globalIndex = selectableMatchedItems.firstIndex(where: { $0.id == matchedItem.id }) {
            let isSelected = globalIndex == commandPalette.selectionIndex

            Button {
                commandPalette.selectionIndex = globalIndex
                commandPalette.handleEnter()
            } label: {
                itemContent(matchedItem, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .id(item.id)
        } else {
            itemContent(matchedItem, isSelected: false)
                .id(item.id)
        }
    }

    @ViewBuilder
    private func itemContent(_ matchedItem: FuzzyMatchedPaletteItem, isSelected: Bool) -> some View {
        let item = matchedItem.item
        let textColor = ThemeManager.current.text
        let subtextColor = ThemeManager.current.subtext0
        let matchColor = ThemeManager.current.blue

        HStack(spacing: 10) {
            // Icon
            if let icon = item.icon {
                iconView(icon, isSelected: isSelected)
            }

            // Title + subtitle with highlighting
            VStack(alignment: .leading, spacing: 2) {
                // Title with optional highlighting
                if let titleMatch = matchedItem.titleMatch, !titleMatch.matchedIndices.isEmpty {
                    FuzzyMatcher.highlightedText(
                        item.displayTitle,
                        matchedIndices: titleMatch.matchedIndices,
                        baseFont: .body,
                        baseColor: textColor,
                        matchColor: matchColor,
                        matchWeight: .bold
                    )
                } else {
                    Text(item.displayTitle)
                        .foregroundColor(textColor)
                }

                // Subtitle with optional highlighting
                if let subtitle = item.subtitle {
                    if let subtitleMatch = matchedItem.subtitleMatch, !subtitleMatch.matchedIndices.isEmpty {
                        FuzzyMatcher.highlightedText(
                            subtitle,
                            matchedIndices: subtitleMatch.matchedIndices,
                            baseFont: .system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded),
                            baseColor: subtextColor,
                            matchColor: matchColor,
                            matchWeight: .bold
                        )
                        .lineLimit(1)
                    } else {
                        Text(subtitle)
                            .font(.system(size: DesignTokens.TypeScale.label, weight: .medium, design: .rounded))
                            .foregroundColor(subtextColor)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Submenu indicator
            if case .submenu = item {
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignTokens.TypeScale.label))
                    .foregroundColor(subtextColor)
            }

            // Shortcut display
            if case let .shortcut(shortcut) = item {
                Text(shortcut.keys)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .monospaced))
                    .foregroundColor(subtextColor)
                    .padding(.horizontal, DesignTokens.Spacing.small)
                    .padding(.vertical, DesignTokens.Spacing.extraSmall)
                    .background(ThemeManager.current.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            }
        }
        .padding(.vertical, DesignTokens.Spacing.small)
        .padding(.horizontal, DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground(isSelected: isSelected))
    }

    @ViewBuilder
    private func iconView(_ icon: CommandPaletteIcon, isSelected: Bool) -> some View {
        let iconColor = isSelected ? ThemeManager.current.text : ThemeManager.current.subtext0

        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(iconColor)
                .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
        case let .asset(name):
            Image(name, bundle: .module)
                .resizable()
                .renderingMode(.original)
                .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
        case .gitlab:
            if let icon = AssetIcon.gitlab() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
            } else {
                Image(systemName: "link")
                    .foregroundColor(iconColor)
                    .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
            }
        case .jira:
            if let icon = AssetIcon.jira() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
            } else {
                Image(systemName: "ticket")
                    .font(.system(size: DesignTokens.TypeScale.body))
                    .foregroundColor(iconColor)
                    .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
            }
        }
    }

    @ViewBuilder
    private var backRow: some View {
        Button {
            commandPalette.navigateBack()
        } label: {
            HStack(spacing: DesignTokens.Spacing.medium) {
                Image(systemName: "chevron.left")
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.subtext0)
                Text("Back")
                    .foregroundColor(ThemeManager.current.subtext0)
                Spacer()
            }
            .padding(.vertical, DesignTokens.Spacing.small)
            .padding(.horizontal, DesignTokens.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading…")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .padding(DesignTokens.Spacing.extraExtraLarge)
    }

    // MARK: - Helpers

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            .fill(isSelected ? ThemeManager.current.surfaceSelected : ThemeManager.current.base)
    }

    /// Capture Ctrl+N/P to move selection in the command palette.
    private func installCommandPaletteMonitor() {
        guard commandPaletteMonitor == nil else { return }
        commandPaletteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard commandPalette.isPresented else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Handle Return/Enter key explicitly to select current item
            if modifiers.isEmpty || modifiers == .numericPad {
                if event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter {
                    commandPalette.handleEnter()
                    return nil
                }
            }

            if modifiers.contains(.control) {
                switch event.keyCode {
                case KeyCode.keyN:
                    commandPalette.moveSelection(delta: 1)
                    return nil
                case KeyCode.keyP:
                    commandPalette.moveSelection(delta: -1)
                    return nil
                default:
                    return event
                }
            }

            if !modifiers.contains(.command), !modifiers.contains(.option) {
                switch event.keyCode {
                case KeyCode.arrowDown:
                    commandPalette.moveSelection(delta: 1)
                    return nil
                case KeyCode.arrowUp:
                    commandPalette.moveSelection(delta: -1)
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }

    /// Remove the command palette key monitor.
    private func removeCommandPaletteMonitor() {
        if let monitor = commandPaletteMonitor {
            NSEvent.removeMonitor(monitor)
            commandPaletteMonitor = nil
        }
    }
}

#Preview {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.commandPalette.isPresented = true
    return CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
        .frame(width: 680, height: 440)
}
