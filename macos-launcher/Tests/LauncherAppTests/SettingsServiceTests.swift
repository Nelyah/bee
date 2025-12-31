import XCTest
@testable import LauncherApp

final class SettingsServiceTests: XCTestCase {
    // Use a dedicated UserDefaults suite to avoid pollution
    private var testDefaults: UserDefaults!
    private var sut: UserDefaultsSettingsService!

    override func setUp() {
        super.setUp()
        // Clear any existing data first - must call on .standard to clear suite
        UserDefaults.standard.removePersistentDomain(forName: "SettingsServiceTests")
        testDefaults = UserDefaults(suiteName: "SettingsServiceTests")!
        sut = UserDefaultsSettingsService(defaults: testDefaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: "SettingsServiceTests")
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - selectedReportName Tests

    func testSelectedReportName_defaultsToEmptyString() {
        XCTAssertEqual(sut.selectedReportName, "")
    }

    func testSelectedReportName_persistsValue() {
        sut.selectedReportName = "my-report"

        // Create new instance to verify persistence
        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertEqual(newService.selectedReportName, "my-report")
    }

    // MARK: - selectedGroupBy Tests

    func testSelectedGroupBy_defaultsToNil() {
        XCTAssertNil(sut.selectedGroupBy)
    }

    func testSelectedGroupBy_persistsValue() {
        sut.selectedGroupBy = "dueDate"

        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertEqual(newService.selectedGroupBy, "dueDate")
    }

    func testSelectedGroupBy_settingNilRemovesValue() {
        sut.selectedGroupBy = "project"
        sut.selectedGroupBy = nil

        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertNil(newService.selectedGroupBy)
    }

    // MARK: - collapsedGroups Tests

    func testCollapsedGroups_defaultsToEmptyArray() {
        XCTAssertEqual(sut.collapsedGroups, [])
    }

    func testCollapsedGroups_persistsValue() {
        sut.collapsedGroups = ["project1", "project2"]

        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertEqual(newService.collapsedGroups, ["project1", "project2"])
    }

    // MARK: - collapsedNilGroup Tests

    func testCollapsedNilGroup_defaultsToFalse() {
        XCTAssertFalse(sut.collapsedNilGroup)
    }

    func testCollapsedNilGroup_persistsValue() {
        sut.collapsedNilGroup = true

        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertTrue(newService.collapsedNilGroup)
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

        let newService = UserDefaultsSettingsService(defaults: testDefaults)
        XCTAssertEqual(newService.collapsedGroups, [])
        XCTAssertFalse(newService.collapsedNilGroup)
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
