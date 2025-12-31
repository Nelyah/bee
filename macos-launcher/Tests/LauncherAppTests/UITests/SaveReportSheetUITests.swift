@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for SaveReportSheet using ViewInspector.
///
/// These tests verify the save report sheet's form elements, validation,
/// and button states across different configurations.
final class SaveReportSheetUITests: XCTestCase {
    // MARK: - Test Setup

    private func makeSUT(
        isPresented: Binding<Bool> = .constant(true),
        currentFilter: JSONValue? = nil,
        filterChipLabels: [String] = [],
        currentColumns: [String] = ["summary", "project"],
        currentColumnNames: [String] = ["Summary", "Project"],
        staticReportNames: Set<String> = [],
        existingUserReportNames: Set<String> = [],
        onSave: @escaping (String, JSONValue?, [String], [String]) -> Void = { _, _, _, _ in }
    ) -> SaveReportSheet {
        SaveReportSheet(
            isPresented: isPresented,
            currentFilter: currentFilter,
            filterChipLabels: filterChipLabels,
            currentColumns: currentColumns,
            currentColumnNames: currentColumnNames,
            staticReportNames: staticReportNames,
            existingUserReportNames: existingUserReportNames,
            onSave: onSave
        )
    }

    // MARK: - Title Tests

    func testDisplaysTitle() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Save Report")
    }

    // MARK: - Form Field Tests

    func testDisplaysReportNameLabel() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Report Name")
    }

    func testDisplaysReportNameTextField() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(ViewType.TextField.self)
    }

    func testDisplaysFiltersSection() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Filters")
    }

    func testDisplaysColumnsSection() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Columns")
    }

    // MARK: - Content Display Tests

    func testDisplaysNoFiltersWhenEmpty() throws {
        let sut = makeSUT(filterChipLabels: [])

        let view = try sut.inspect()

        _ = try view.find(text: "No filters")
    }

    func testDisplaysFilterChipLabels() throws {
        let sut = makeSUT(filterChipLabels: ["status:pending", "project:api"])

        let view = try sut.inspect()

        _ = try view.find(text: "status:pending • project:api")
    }

    func testDisplaysColumnNames() throws {
        let sut = makeSUT(currentColumnNames: ["Summary", "Project", "Tags"])

        let view = try sut.inspect()

        _ = try view.find(text: "Summary, Project, Tags")
    }

    // MARK: - Button Tests

    func testDisplaysCancelButton() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Cancel")
    }

    func testDisplaysSaveButton() throws {
        let sut = makeSUT()

        let view = try sut.inspect()

        _ = try view.find(text: "Save")
    }

    func testCancelButtonDismissesSheet() throws {
        var isPresented = true
        let binding = Binding(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let sut = makeSUT(isPresented: binding)

        let view = try sut.inspect()
        let cancelButton = try view.find(button: "Cancel")
        try cancelButton.tap()

        XCTAssertFalse(isPresented)
    }

    // MARK: - Validation Tests

    // Note: Testing text field input and validation with ViewInspector is limited
    // because @State changes don't propagate during inspection.
    // Full validation behavior is better tested via snapshot tests showing error states.

    func testSaveButtonExists() throws {
        let sut = makeSUT()

        let view = try sut.inspect()
        let saveButton = try view.find(button: "Save")

        XCTAssertNotNil(saveButton)
    }
}
