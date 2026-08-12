import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var scheduledFor: Date
    var completedAt: Date?
    var updatedAt: Date

    var isCompleted: Bool { completedAt != nil }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        scheduledFor: Date = Date(),
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
