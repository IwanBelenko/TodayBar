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
        case .none: return L10n.text("Без приоритета", "No priority")
        case .low: return L10n.text("Низкий", "Low")
        case .medium: return L10n.text("Средний", "Medium")
        case .high: return L10n.text("Высокий", "High")
        }
    }

    var menuTitle: String {
        switch self {
        case .none: return title
        case .low: return L10n.text("Низкий · 1 огонёк", "Low · 1 flame")
        case .medium: return L10n.text("Средний · 2 огонька", "Medium · 2 flames")
        case .high: return L10n.text("Высокий · 3 огонька", "High · 3 flames")
        }
    }
}
