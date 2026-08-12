import Foundation

struct TaskCategory: Codable, Identifiable, Equatable, Hashable {
    static let workID = UUID(uuidString: "A91B6B75-5BF2-45F4-B00D-1C24F6DBF001")!
    static let personalID = UUID(uuidString: "A91B6B75-5BF2-45F4-B00D-1C24F6DBF002")!

    static let defaults = [
        TaskCategory(id: workID, name: "Работа", systemImage: "briefcase"),
        TaskCategory(id: personalID, name: "Личное", systemImage: "person")
    ]

    let id: UUID
    var name: String
    var systemImage: String

    init(id: UUID = UUID(), name: String, systemImage: String = "folder") {
        self.id = id
        self.name = name
        self.systemImage = systemImage
    }
}
