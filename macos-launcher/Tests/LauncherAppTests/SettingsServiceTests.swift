@testable import LauncherApp
import XCTest

final class SettingsServiceTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var sut: UserDefaultsSettingsService!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // Generate unique suite name per test instance to ensure complete isolation
        suiteName = "com.bee.test.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        sut = UserDefaultsSettingsService(defaults: testDefaults)
    }

    override func tearDown() {
        // Clean up the persistent domain
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        sut = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - selectedReportName Tests

    func testSelectedReportName_defaultsToEmptyString() {
        XCTAssertEqual(sut.selectedReportName, "")
    }

    func testSelectedReportName_persistsValue() {
        sut.selectedReportName = "my-report"

        // Verify reading back through the service
        XCTAssertEqual(sut.selectedReportName, "my-report")
    }

    // MARK: - selectedGroupBy Tests

    func testSelectedGroupBy_defaultsToNil() {
        XCTAssertNil(sut.selectedGroupBy)
    }

    func testSelectedGroupBy_persistsValue() {
        sut.selectedGroupBy = "dueDate"

        // Verify reading back through the service
        XCTAssertEqual(sut.selectedGroupBy, "dueDate")
    }

    func testSelectedGroupBy_settingNilRemovesValue() {
        sut.selectedGroupBy = "project"
        sut.selectedGroupBy = nil

        // Verify reading back through the service
        XCTAssertNil(sut.selectedGroupBy)
    }

    // MARK: - collapsedGroups Tests

    func testCollapsedGroups_defaultsToEmptyArray() {
        XCTAssertEqual(sut.collapsedGroups, [])
    }

    func testCollapsedGroups_persistsValue() {
        sut.collapsedGroups = ["project1", "project2"]

        // Verify reading back through the service
        XCTAssertEqual(sut.collapsedGroups, ["project1", "project2"])
    }

    // MARK: - collapsedNilGroup Tests

    func testCollapsedNilGroup_defaultsToFalse() {
        XCTAssertFalse(sut.collapsedNilGroup)
    }

    func testCollapsedNilGroup_persistsValue() {
        sut.collapsedNilGroup = true

        // Verify reading back through the service
        XCTAssertTrue(sut.collapsedNilGroup)
    }

    // MARK: - clearCollapsedState Tests

    func testClearCollapsedState_removesCollapsedGroups() {
        sut.collapsedGroups = ["project1"]
        sut.collapsedNilGroup = true

        sut.clearCollapsedState()

        XCTAssertEqual(sut.collapsedGroups, [])
        XCTAssertFalse(sut.collapsedNilGroup)
    }

    func testClearCollapsedState_persistsClearedState() {
        sut.collapsedGroups = ["project1"]
        sut.collapsedNilGroup = true

        sut.clearCollapsedState()

        // Verify the values were cleared through the service API
        XCTAssertEqual(sut.collapsedGroups, [])
        XCTAssertFalse(sut.collapsedNilGroup)
    }
}

// MARK: - MockSettingsService Tests

final class MockSettingsServiceTests: XCTestCase {
    func testDefaultValues() {
        let sut = MockSettingsService()

        XCTAssertEqual(sut.selectedReportName, "")
        XCTAssertNil(sut.selectedGroupBy)
        XCTAssertEqual(sut.collapsedGroups, [])
        XCTAssertFalse(sut.collapsedNilGroup)
        XCTAssertFalse(sut.clearCollapsedStateCalled)
    }

    func testClearCollapsedState_tracksCalls() {
        let sut = MockSettingsService()
        sut.collapsedGroups = ["test"]
        sut.collapsedNilGroup = true

        sut.clearCollapsedState()

        XCTAssertTrue(sut.clearCollapsedStateCalled)
        XCTAssertEqual(sut.collapsedGroups, [])
        XCTAssertFalse(sut.collapsedNilGroup)
    }

    func testReset_clearsAllState() {
        let sut = MockSettingsService()
        sut.selectedReportName = "report"
        sut.selectedGroupBy = "dueDate"
        sut.collapsedGroups = ["test"]
        sut.collapsedNilGroup = true
        sut.clearCollapsedState()

        sut.reset()

        XCTAssertEqual(sut.selectedReportName, "")
        XCTAssertNil(sut.selectedGroupBy)
        XCTAssertEqual(sut.collapsedGroups, [])
        XCTAssertFalse(sut.collapsedNilGroup)
        XCTAssertFalse(sut.clearCollapsedStateCalled)
    }
}
