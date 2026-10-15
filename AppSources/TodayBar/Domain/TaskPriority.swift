import Foundation

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high

    var id: Self { self }

    var flameCount: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var title: String {
        switch self {
        case .none: return "Без приоритета"
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }

    var menuTitle: String {
        switch self {
        case .none: return title
        case .low: return "Низкий · 1 огонёк"
        case .medium: return "Средний · 2 огонька"
        case .high: return "Высокий · 3 огонька"
        }
    }
}
