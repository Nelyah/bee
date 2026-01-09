import XCTest

@testable import LauncherAppKit

final class ProjectStatsModelsTests: XCTestCase {
    // MARK: - ProjectStats Tests

    func testProjectStatsDecoding() throws {
        let json = """
        {
            "name": "backend",
            "pending_count": 5,
            "active_count": 2,
            "completed_count": 10,
            "overdue_count": 1,
            "total_count": 18
        }
        """

        let data = Data(json.utf8)
        let stats = try JSONDecoder().decode(ProjectStats.self, from: data)

        XCTAssertEqual(stats.name, "backend")
        XCTAssertEqual(stats.pendingCount, 5)
        XCTAssertEqual(stats.activeCount, 2)
        XCTAssertEqual(stats.completedCount, 10)
        XCTAssertEqual(stats.overdueCount, 1)
        XCTAssertEqual(stats.totalCount, 18)
    }

    // MARK: - ProjectNode Tests

    func testProjectNodeDecoding() throws {
        let json = """
        {
            "name": "api",
            "full_path": "backend.api",
            "stats": {
                "name": "backend.api",
                "pending_count": 3,
                "active_count": 1,
                "completed_count": 5,
                "overdue_count": 0,
                "total_count": 9
            },
            "children": []
        }
        """

        let data = Data(json.utf8)
        let node = try JSONDecoder().decode(ProjectNode.self, from: data)

        XCTAssertEqual(node.name, "api")
        XCTAssertEqual(node.fullPath, "backend.api")
        XCTAssertEqual(node.stats.pendingCount, 3)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testProjectNodeWithChildren() throws {
        let json = """
        {
            "name": "backend",
            "full_path": "backend",
            "stats": {
                "name": "backend",
                "pending_count": 5,
                "active_count": 2,
                "completed_count": 10,
                "overdue_count": 1,
                "total_count": 18
            },
            "children": [
                {
                    "name": "api",
                    "full_path": "backend.api",
                    "stats": {
                        "name": "backend.api",
                        "pending_count": 3,
                        "active_count": 1,
                        "completed_count": 5,
                        "overdue_count": 0,
                        "total_count": 9
                    },
                    "children": []
                },
                {
                    "name": "db",
                    "full_path": "backend.db",
                    "stats": {
                        "name": "backend.db",
                        "pending_count": 2,
                        "active_count": 1,
                        "completed_count": 5,
                        "overdue_count": 1,
                        "total_count": 9
                    },
                    "children": []
                }
            ]
        }
        """

        let data = Data(json.utf8)
        let node = try JSONDecoder().decode(ProjectNode.self, from: data)

        XCTAssertEqual(node.name, "backend")
        XCTAssertEqual(node.fullPath, "backend")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].name, "api")
        XCTAssertEqual(node.children[1].name, "db")
    }

    func testProjectNodeHasChildrenProperty() throws {
        let nodeWithChildren = ProjectNode(
            name: "parent",
            fullPath: "parent",
            stats: ProjectStats(
                name: "parent",
                pendingCount: 1,
                activeCount: 0,
                completedCount: 0,
                overdueCount: 0,
                totalCount: 1
            ),
            children: [
                ProjectNode(
                    name: "child",
                    fullPath: "parent.child",
                    stats: ProjectStats(
                        name: "parent.child",
                        pendingCount: 0,
                        activeCount: 0,
                        completedCount: 0,
                        overdueCount: 0,
                        totalCount: 0
                    ),
                    children: []
                ),
            ]
        )

        let nodeWithoutChildren = ProjectNode(
            name: "leaf",
            fullPath: "leaf",
            stats: ProjectStats(
                name: "leaf",
                pendingCount: 0,
                activeCount: 0,
                completedCount: 0,
                overdueCount: 0,
                totalCount: 0
            ),
            children: []
        )

        XCTAssertTrue(nodeWithChildren.hasChildren)
        XCTAssertFalse(nodeWithoutChildren.hasChildren)
    }

    func testProjectNodeIdentifiable() {
        let node = ProjectNode(
            name: "test",
            fullPath: "project.test",
            stats: ProjectStats(
                name: "project.test",
                pendingCount: 0,
                activeCount: 0,
                completedCount: 0,
                overdueCount: 0,
                totalCount: 0
            ),
            children: []
        )

        // id should be the fullPath
        XCTAssertEqual(node.id, "project.test")
    }

    // MARK: - ProjectsResponse Tests

    func testProjectsResponseDecoding() throws {
        let json = """
        {
            "projects": [
                {
                    "name": "frontend",
                    "full_path": "frontend",
                    "stats": {
                        "name": "frontend",
                        "pending_count": 3,
                        "active_count": 1,
                        "completed_count": 8,
                        "overdue_count": 0,
                        "total_count": 12
                    },
                    "children": []
                }
            ]
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(ProjectsResponse.self, from: data)

        XCTAssertEqual(response.projects.count, 1)
        XCTAssertEqual(response.projects[0].name, "frontend")
    }

    // MARK: - BurndownDataPoint Tests

    func testBurndownDataPointDecoding() throws {
        let json = """
        {
            "date": "2024-01-15",
            "completed_cumulative": 5,
            "remaining": 10
        }
        """

        let data = Data(json.utf8)
        let point = try JSONDecoder().decode(BurndownDataPoint.self, from: data)

        XCTAssertEqual(point.date, "2024-01-15")
        XCTAssertEqual(point.completedCumulative, 5)
        XCTAssertEqual(point.remaining, 10)
    }

    func testBurndownDataPointDateValue() {
        let point = BurndownDataPoint(
            date: "2024-06-15",
            completedCumulative: 10,
            remaining: 5
        )

        XCTAssertNotNil(point.dateValue)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: point.dateValue!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testBurndownDataPointInvalidDateReturnsNil() {
        let point = BurndownDataPoint(
            date: "invalid-date",
            completedCumulative: 0,
            remaining: 0
        )

        XCTAssertNil(point.dateValue)
    }

    func testBurndownDataPointIdentifiable() {
        let point = BurndownDataPoint(
            date: "2024-01-15",
            completedCumulative: 5,
            remaining: 10
        )

        // id should be the date string
        XCTAssertEqual(point.id, "2024-01-15")
    }

    // MARK: - ProjectBurndownResponse Tests

    func testProjectBurndownResponseDecoding() throws {
        let json = """
        {
            "project": "backend",
            "data_points": [
                {
                    "date": "2024-01-01",
                    "completed_cumulative": 0,
                    "remaining": 20
                },
                {
                    "date": "2024-01-15",
                    "completed_cumulative": 5,
                    "remaining": 15
                }
            ],
            "total_tasks": 20,
            "total_completed": 5
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(ProjectBurndownResponse.self, from: data)

        XCTAssertEqual(response.project, "backend")
        XCTAssertEqual(response.dataPoints.count, 2)
        XCTAssertEqual(response.totalTasks, 20)
        XCTAssertEqual(response.totalCompleted, 5)
    }

    // MARK: - Equatable Tests

    func testProjectStatsEquatable() {
        let stats1 = ProjectStats(
            name: "test",
            pendingCount: 1,
            activeCount: 2,
            completedCount: 3,
            overdueCount: 4,
            totalCount: 10
        )
        let stats2 = ProjectStats(
            name: "test",
            pendingCount: 1,
            activeCount: 2,
            completedCount: 3,
            overdueCount: 4,
            totalCount: 10
        )
        let stats3 = ProjectStats(
            name: "different",
            pendingCount: 1,
            activeCount: 2,
            completedCount: 3,
            overdueCount: 4,
            totalCount: 10
        )

        XCTAssertEqual(stats1, stats2)
        XCTAssertNotEqual(stats1, stats3)
    }

    func testProjectNodeEquatable() {
        let node1 = ProjectNode(
            name: "test",
            fullPath: "test",
            stats: ProjectStats(
                name: "test",
                pendingCount: 1,
                activeCount: 0,
                completedCount: 0,
                overdueCount: 0,
                totalCount: 1
            ),
            children: []
        )
        let node2 = ProjectNode(
            name: "test",
            fullPath: "test",
            stats: ProjectStats(
                name: "test",
                pendingCount: 1,
                activeCount: 0,
                completedCount: 0,
                overdueCount: 0,
                totalCount: 1
            ),
            children: []
        )

        XCTAssertEqual(node1, node2)
    }
}
