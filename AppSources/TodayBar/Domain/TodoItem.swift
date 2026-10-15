import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var scheduledFor: Date
    var categoryID: UUID?
    var dueDate: Date?
    var completedAt: Date?
    var updatedAt: Date
    var priority: TaskPriority

    var isCompleted: Bool { completedAt != nil }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        scheduledFor: Date = Date(),
        categoryID: UUID? = nil,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = Date(),
        priority: TaskPriority = .none
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.categoryID = categoryID
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.priority = priority
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, scheduledFor, categoryID, dueDate, completedAt, updatedAt, priority
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        scheduledFor = try values.decode(Date.self, forKey: .scheduledFor)
        categoryID = try values.decodeIfPresent(UUID.self, forKey: .categoryID)
        dueDate = try values.decodeIfPresent(Date.self, forKey: .dueDate)
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        // Existing task files have no priority; unknown future levels remain readable too.
        let rawPriority = try values.decodeIfPresent(String.self, forKey: .priority)
        priority = rawPriority.flatMap(TaskPriority.init(rawValue:)) ?? .none
    }
}
