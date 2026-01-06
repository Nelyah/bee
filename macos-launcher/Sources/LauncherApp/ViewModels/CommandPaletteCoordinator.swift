import Combine
import Foundation

@MainActor
final class CommandPaletteCoordinator: ObservableObject {
    private var queryCancellable: AnyCancellable?
    @Published private(set) var debouncedQuery: String = ""

    private var cachedSections: [CommandPaletteSection] = []
    private var cachedQuery: String = ""
    private var cachedMenuId: String = ""
    private var cachedMenuDepth: Int = -1

    // MARK: - Published State

    @Published var isPresented: Bool = false
    @Published var query: String = ""
    @Published var selectionIndex: Int = 0
    @Published var isLoading: Bool = false

    // MARK: - Navigation Stack

    @Published private(set) var navigationStack = CommandPaletteStack()

    // MARK: - Dependencies

    let dataSource: CommandPaletteDataSource

    // MARK: - Context

    private(set) var context: CommandPaletteContext = .init()

    // MARK: - Computed Properties

    /// All sections for the current menu, filtered by query.
    var currentSections: [CommandPaletteSection] {
        let effectiveQuery = debouncedQuery

        let signature = currentMenuSignature()
        if cachedQuery == effectiveQuery,
           cachedMenuId == signature.id,
           cachedMenuDepth == signature.depth {
            return cachedSections
        }

        let sections: [CommandPaletteSection] = if let menu = navigationStack.currentMenu, !navigationStack.isAtRoot {
            dataSource.filterSections(menu.sections, query: effectiveQuery)
        } else {
            dataSource.buildSections(context: context, query: effectiveQuery)
        }

        cachedQuery = effectiveQuery
        cachedMenuId = signature.id
        cachedMenuDepth = signature.depth
        cachedSections = sections
        return sections
    }

    /// Flat list of all selectable items for keyboard navigation.
    var selectableItems: [CommandPaletteItem] {
        currentSections.flatMap { $0.items.filter(\.isSelectable) }
    }

    /// Flat list of selectable matched items with fuzzy match info (for highlighting).
    var selectableMatchedItems: [FuzzyMatchedPaletteItem] {
        currentSections.flatMap { $0.matchedItems.filter(\.item.isSelectable) }
    }

    /// The currently selected item based on selection index.
    var selectedItem: CommandPaletteItem? {
        guard selectionIndex >= 0, selectionIndex < selectableItems.count else { return nil }
        return selectableItems[selectionIndex]
    }

    /// Whether the navigation stack is at root level.
    var isAtRoot: Bool { navigationStack.isAtRoot }

    /// Breadcrumb path for display in nested menus.
    var breadcrumb: [String] { navigationStack.breadcrumb }

    // MARK: - Initialization

    init(dataSource: CommandPaletteDataSource) {
        self.dataSource = dataSource
        debouncedQuery = query
        queryCancellable = $query
            .removeDuplicates()
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                debouncedQuery = value
                invalidateCache()
            }
    }

    convenience init() {
        self.init(dataSource: CommandPaletteDataSource())
    }

    // MARK: - Lifecycle

    /// Opens the command palette with the given context.
    ///
    /// - Parameter context: The context containing task selection, reports, etc.
    /// - Returns: An error message if it cannot be opened, or nil on success.
    func open(context: CommandPaletteContext) -> String? {
        self.context = context
        resetForOpen()
        let rootMenu = buildRootMenu()
        navigationStack.reset(to: rootMenu)
        isPresented = true
        return nil
    }

    /// Closes the command palette and resets state.
    func close() {
        isPresented = false
        navigationStack.clear()
        resetForOpen()
    }

    /// Resets state for opening the palette.
    func resetForOpen() {
        query = ""
        debouncedQuery = query
        invalidateCache()
        selectionIndex = 0
        isLoading = false
    }

    /// Resets selection index to 0.
    func resetSelection() {
        selectionIndex = 0
    }

    // MARK: - Navigation (New Architecture)

    /// Handles escape key press.
    ///
    /// - Returns: True if escape was handled (popped stack), false if at root (should close).
    func handleEscape() -> Bool {
        if navigationStack.pop() {
            query = ""
            debouncedQuery = query
            invalidateCache()
            selectionIndex = 0
            return true
        }
        return false
    }

    /// Handles enter key press on the selected item.
    func handleEnter() {
        guard let item = selectedItem else { return }

        switch item {
        case let .submenu(submenu):
            let menu = submenu.menuBuilder()
            navigationStack.push(menu)
            query = ""
            debouncedQuery = query
            invalidateCache()
            selectionIndex = 0

        case let .action(action):
            action.handler()

        case let .suggestion(suggestion):
            suggestion.handler()

        case .shortcut:
            // Shortcuts are display-only
            break
        }
    }

    /// Navigates back one level in the stack.
    func navigateBack() {
        _ = navigationStack.pop()
        query = ""
        debouncedQuery = query
        invalidateCache()
        selectionIndex = 0
    }

    /// Pushes a new menu onto the navigation stack.
    func pushMenu(_ menu: CommandPaletteMenu) {
        navigationStack.push(menu)
        query = ""
        debouncedQuery = query
        invalidateCache()
        selectionIndex = 0
    }

    // MARK: - Selection

    /// Moves selection by the given delta.
    func moveSelection(delta: Int) {
        let count = selectableItems.count
        guard count > 0 else {
            selectionIndex = 0
            return
        }
        let next = max(0, min(selectionIndex + delta, count - 1))
        selectionIndex = next
    }

    // MARK: - Context Updates

    /// Updates the palette context.
    func updateContext(_ context: CommandPaletteContext) {
        self.context = context
        invalidateCache()
    }

    // MARK: - Private Helpers

    private func buildRootMenu() -> CommandPaletteMenu {
        let sections = dataSource.buildSections(context: context, query: query)
        return CommandPaletteMenu(
            id: "root",
            title: "Command Palette",
            sections: sections
        )
    }

    private func currentMenuSignature() -> (id: String, depth: Int) {
        if let menu = navigationStack.currentMenu {
            return (menu.id, navigationStack.breadcrumb.count)
        }
        return ("root", 0)
    }

    private func invalidateCache() {
        cachedQuery = ""
        cachedMenuId = ""
        cachedMenuDepth = -1
        cachedSections = []
    }
}
