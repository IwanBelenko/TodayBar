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

    var isCompleted: Bool { completedAt != nil }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        scheduledFor: Date = Date(),
        categoryID: UUID? = nil,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.categoryID = categoryID
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
