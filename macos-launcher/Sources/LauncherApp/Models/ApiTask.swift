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
    let datePlanned: String?
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
        case datePlanned = "date_planned"
        case urgency
    }
}

struct TaskAnnotationDto: Decodable, Identifiable, Equatable {
    let value: String
    let time: String

    var id: String { "\(time)-\(value)" }
}

struct TaskHistoryDto: Decodable, Identifiable {
    let value: String
    let datetime: String

    var id: String { "\(datetime)-\(value)" }
}

/// DTO for file attachments.
struct TaskAttachmentDto: Decodable, Identifiable, Equatable {
    let id: Int
    let uuid: String
    let filename: String
    let mimeType: String
    let sizeBytes: Int64
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case filename
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
    }

    /// Human-readable file size.
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    /// SF Symbol name based on MIME type.
    var iconName: String {
        if mimeType.hasPrefix("image/") {
            "photo"
        } else if mimeType.hasPrefix("video/") {
            "video"
        } else if mimeType.hasPrefix("audio/") {
            "waveform"
        } else if mimeType == "application/pdf" {
            "doc.text"
        } else if mimeType.contains("spreadsheet") || mimeType.contains("excel") {
            "tablecells"
        } else if mimeType.contains("document") || mimeType.contains("word") {
            "doc.richtext"
        } else if mimeType.contains("zip") || mimeType.contains("archive") || mimeType.contains("compressed") {
            "archivebox"
        } else {
            "doc"
        }
    }
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

/// DTO for email links (references to emails in Apple Mail).
struct EmailLinkDto: Decodable, Identifiable, Equatable {
    let id: Int
    let uuid: String
    let messageId: String
    let subject: String
    let sender: String
    let sentDate: String?
    let createdAt: String
    let mailUrl: String

    private enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case messageId = "message_id"
        case subject
        case sender
        case sentDate = "sent_date"
        case createdAt = "created_at"
        case mailUrl = "mail_url"
    }
}

/// DTO for important links (user-defined URLs attached to tasks).
struct ImportantLinkDto: Decodable, Identifiable, Equatable {
    let id: Int
    let uuid: String
    let url: String
    let title: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case url
        case title
        case createdAt = "created_at"
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
    let datePlanned: String?
    let urgency: Int?
    let annotations: [TaskAnnotationDto]
    let history: [TaskHistoryDto]
    let links: [TaskLinkDto]
    let attachments: [TaskAttachmentDto]
    let emailLinks: [EmailLinkDto]
    let importantLinks: [ImportantLinkDto]

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
        case datePlanned = "date_planned"
        case urgency
        case annotations
        case history
        case links
        case attachments
        case emailLinks = "email_links"
        case importantLinks = "important_links"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dbId = try container.decodeIfPresent(Int.self, forKey: .dbId)
        uuid = try container.decode(String.self, forKey: .uuid)
        status = try container.decode(String.self, forKey: .status)
        summary = try container.decode(String.self, forKey: .summary)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        tags = try container.decode([String].self, forKey: .tags)
        dateCreated = try container.decode(String.self, forKey: .dateCreated)
        dateCompleted = try container.decodeIfPresent(String.self, forKey: .dateCompleted)
        dateDue = try container.decodeIfPresent(String.self, forKey: .dateDue)
        datePlanned = try container.decodeIfPresent(String.self, forKey: .datePlanned)
        urgency = try container.decodeIfPresent(Int.self, forKey: .urgency)
        annotations = try container.decode([TaskAnnotationDto].self, forKey: .annotations)
        history = try container.decode([TaskHistoryDto].self, forKey: .history)
        links = try container.decode([TaskLinkDto].self, forKey: .links)
        // Backwards compatibility: default to empty array if attachments not present
        attachments = try container.decodeIfPresent([TaskAttachmentDto].self, forKey: .attachments) ?? []
        // Backwards compatibility: default to empty array if email_links not present
        emailLinks = try container.decodeIfPresent([EmailLinkDto].self, forKey: .emailLinks) ?? []
        // Backwards compatibility: default to empty array if important_links not present
        importantLinks = try container.decodeIfPresent([ImportantLinkDto].self, forKey: .importantLinks) ?? []
    }

    // For test/preview convenience
    init(
        dbId: Int?,
        uuid: String,
        status: String,
        summary: String,
        project: String?,
        tags: [String],
        dateCreated: String,
        dateCompleted: String?,
        dateDue: String?,
        datePlanned: String?,
        urgency: Int?,
        annotations: [TaskAnnotationDto],
        history: [TaskHistoryDto],
        links: [TaskLinkDto],
        attachments: [TaskAttachmentDto],
        emailLinks: [EmailLinkDto] = [],
        importantLinks: [ImportantLinkDto] = []
    ) {
        self.dbId = dbId
        self.uuid = uuid
        self.status = status
        self.summary = summary
        self.project = project
        self.tags = tags
        self.dateCreated = dateCreated
        self.dateCompleted = dateCompleted
        self.dateDue = dateDue
        self.datePlanned = datePlanned
        self.urgency = urgency
        self.annotations = annotations
        self.history = history
        self.links = links
        self.attachments = attachments
        self.emailLinks = emailLinks
        self.importantLinks = importantLinks
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
