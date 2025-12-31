import Foundation

// MARK: - Selection & Navigation

extension LauncherViewModel {
    /// Move the selection by a delta, clamping at list boundaries (skipping group headers).
    /// Also exits insert mode when navigating.
    func moveSelection(delta: Int) {
        exitInsertMode(restoreSelection: false)
        let rows = groupedRows
        let nextIndex = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: selectedRowIndex,
            delta: delta
        )
        updateSelection(rowIndex: nextIndex, rows: rows)
    }

    /// Select the first row in the list.
    func selectFirstRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: 0, rows: rows)
    }

    /// Select the last row in the list.
    func selectLastRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rows.count - 1, rows: rows)
    }

    /// Enter insert mode, focusing the text input.
    func enterInsertMode() {
        lastSelectedRowIndex = selectedRowIndex
        isInsertMode = true
        updateSelection(rowIndex: nil)
    }

    func exitInsertMode(restoreSelection: Bool = true) {
        guard isInsertMode else { return }
        isInsertMode = false
        if restoreSelection, selectedRowIndex == nil, let lastSelectedRowIndex {
            updateSelection(rowIndex: lastSelectedRowIndex)
        }
    }

    func selectRow(_ rowIndex: Int) {
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rowIndex)
    }

    func activatePrimary(at rowIndex: Int) {
        let rows = groupedRows
        guard rowIndex >= 0, rowIndex < rows.count else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rowIndex, rows: rows)
        switch rows[rowIndex] {
        case let .header(header):
            toggleGroupCollapse(header.key)
        case .task:
            openDetail()
        }
    }

    func updateSelection(rowIndex: Int?, rows: [GroupedListRow]? = nil) {
        let currentRows = rows ?? groupedRows
        selectedRowIndex = rowIndex
        if let rowIndex, rowIndex < currentRows.count {
            if case let .task(item) = currentRows[rowIndex] {
                selectedIndex = item.flatIndex
            }
        } else {
            selectedIndex = nil
        }
        if !isInsertMode {
            lastSelectedRowIndex = rowIndex
        }
    }
}
