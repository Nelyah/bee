import Foundation

struct ApiTask: Decodable, Identifiable {
    let dbId: Int?
    let uuid: String
    let status: String
    let summary: String
    let project: String?
    let tags: [String]
    let dateCreated: String
    let dateCompleted: String?
    let dateDue: String?
    let urgency: Int?

    var id: String { uuid }

    private enum CodingKeys: String, CodingKey {
        case dbId = "id"
        case uuid
        case status
        case summary
        case project
        case tags
        case dateCreated = "date_created"
        case dateCompleted = "date_completed"
        case dateDue = "date_due"
        case urgency
    }
}

struct TaskAnnotationDto: Decodable, Identifiable {
    let value: String
    let time: String

    var id: String { "\(time)-\(value)" }
}

struct TaskHistoryDto: Decodable, Identifiable {
    let value: String
    let datetime: String

    var id: String { "\(datetime)-\(value)" }
}

/// Link type enum with display names and icons
enum LinkType: String, CaseIterable {
    case dependsOn = "depends_on"
    case blocking
    case parentOf = "parent_of"
    case childOf = "child_of"
    case relatedTo = "related_to"
    case duplicates

    /// Display name for showing in the UI (active form)
    var displayName: String {
        switch self {
        case .dependsOn: "Depends on"
        case .blocking: "Blocks"
        case .parentOf: "Parent of"
        case .childOf: "Child of"
        case .relatedTo: "Related to"
        case .duplicates: "Duplicates"
        }
    }

    /// SF Symbol icon name for this link type
    var iconName: String {
        switch self {
        case .dependsOn: "arrow.left"
        case .blocking: "arrow.right"
        case .parentOf: "arrow.up"
        case .childOf: "arrow.down"
        case .relatedTo: "link"
        case .duplicates: "doc.on.doc"
        }
    }
}

struct TaskLinkDto: Decodable, Identifiable, Equatable {
    let linkType: String
    let targetUuid: String

    var id: String { "\(linkType)-\(targetUuid)" }

    /// Parsed link type enum (nil if unknown)
    var type: LinkType? {
        LinkType(rawValue: linkType)
    }

    private enum CodingKeys: String, CodingKey {
        case linkType = "link_type"
        case targetUuid = "target_uuid"
    }
}

struct ApiTaskDetail: Decodable, Identifiable {
    let dbId: Int?
    let uuid: String
    let status: String
    let summary: String
    let project: String?
    let tags: [String]
    let dateCreated: String
    let dateCompleted: String?
    let dateDue: String?
    let urgency: Int?
    let annotations: [TaskAnnotationDto]
    let history: [TaskHistoryDto]
    let links: [TaskLinkDto]

    var id: String { uuid }

    private enum CodingKeys: String, CodingKey {
        case dbId = "id"
        case uuid
        case status
        case summary
        case project
        case tags
        case dateCreated = "date_created"
        case dateCompleted = "date_completed"
        case dateDue = "date_due"
        case urgency
        case annotations
        case history
        case links
    }

    /// Group links by type for display
    func linksByType() -> [LinkType: [TaskLinkDto]] {
        var grouped: [LinkType: [TaskLinkDto]] = [:]
        for link in links {
            if let type = link.type {
                grouped[type, default: []].append(link)
            }
        }
        return grouped
    }
}
