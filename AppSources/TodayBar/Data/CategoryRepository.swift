import Foundation

@MainActor
protocol CategoryRepository {
    func load() throws -> [TaskCategory]
    func save(_ categories: [TaskCategory]) throws
}
