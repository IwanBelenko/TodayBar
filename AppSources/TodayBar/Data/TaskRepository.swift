import Foundation

@MainActor
protocol TaskRepository {
    func load() throws -> [TodoItem]
    func save(_ tasks: [TodoItem]) throws
}
