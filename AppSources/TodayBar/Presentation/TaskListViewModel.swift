import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoItem] = []
    @Published var errorMessage: String?

    private let repository: TaskRepository
    private let calendar: Calendar
    private let now: () -> Date

    init(
        repository: TaskRepository,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        reload()
    }

    var todayPending: [TodoItem] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var todayCompleted: [TodoItem] {
        let today = now()
        return tasks
            .filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: today)
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var completedHistory: [TodoItem] {
        tasks
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func add(title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let timestamp = now()
        tasks.append(TodoItem(title: cleaned, createdAt: timestamp, scheduledFor: timestamp, updatedAt: timestamp))
        persist()
    }

    func updateTitle(id: UUID, title: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = title
        tasks[index].updatedAt = now()
        persist()
    }

    func finishEditing(id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delete(id: id)
        }
    }

    func toggleCompleted(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let timestamp = now()
        tasks[index].completedAt = tasks[index].isCompleted ? nil : timestamp
        tasks[index].updatedAt = timestamp
        persist()
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    func clearHistory() {
        tasks.removeAll { $0.isCompleted }
        persist()
    }

    private func reload() {
        do {
            tasks = try repository.load()
        } catch {
            errorMessage = "Не удалось прочитать сохранённые дела."
        }
    }

    private func persist() {
        do {
            try repository.save(tasks)
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сохранить изменения."
        }
    }
}
