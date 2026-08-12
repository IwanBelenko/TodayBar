import Foundation

@MainActor
final class JSONCategoryRepository: CategoryRepository {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
    }

    func load() throws -> [TaskCategory] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return TaskCategory.defaults }
        let categories = try decoder.decode([TaskCategory].self, from: Data(contentsOf: fileURL))
        let systemIDs = Set(TaskCategory.defaults.map(\.id))
        let customCategories = categories.filter { !systemIDs.contains($0.id) }
        return TaskCategory.defaults + customCategories
    }

    func save(_ categories: [TaskCategory]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(categories).write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("TodayBar", isDirectory: true)
            .appendingPathComponent("categories.json")
    }
}
