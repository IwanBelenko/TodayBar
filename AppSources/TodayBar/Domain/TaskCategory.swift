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

    var displayName: String {
        switch id {
        case Self.workID: return L10n.text("Работа", "Work")
        case Self.personalID: return L10n.text("Личное", "Personal")
        default: return name
        }
    }

    init(id: UUID = UUID(), name: String, systemImage: String = "folder") {
        self.id = id
        self.name = name
        self.systemImage = systemImage
    }
}
