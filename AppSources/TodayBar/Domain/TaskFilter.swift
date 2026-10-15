import Foundation

/// A single search rule for both the current list and the archive.
struct TaskFilter {
    let categoryID: UUID?
    private let terms: [String]

    init(query: String, categoryID: UUID? = nil) {
        self.categoryID = categoryID
        terms = Self.normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var isSearching: Bool { !terms.isEmpty }

    func matches(_ task: TodoItem) -> Bool {
        guard categoryID == nil || task.categoryID == categoryID else { return false }
        let title = Self.normalized(task.title)
        return terms.allSatisfy { title.contains($0) }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
