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
    }
}
