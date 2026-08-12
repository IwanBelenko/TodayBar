import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoItem] = []
    @Published private(set) var categories: [TaskCategory] = []
    @Published var errorMessage: String?

    private let repository: TaskRepository
    private let categoryRepository: CategoryRepository
    private let reminderScheduler: ReminderScheduling
    private let calendar: Calendar
    private let now: () -> Date

    init(
        repository: TaskRepository,
        categoryRepository: CategoryRepository,
        reminderScheduler: ReminderScheduling,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.categoryRepository = categoryRepository
        self.reminderScheduler = reminderScheduler
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

    var overdueCount: Int {
        let timestamp = now()
        return tasks.filter { !$0.isCompleted && ($0.dueDate ?? .distantFuture) < timestamp }.count
    }

    func add(title: String, categoryID: UUID?, dueDate: Date?) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let timestamp = now()
        let task = TodoItem(
            title: cleaned,
            createdAt: timestamp,
            scheduledFor: timestamp,
            categoryID: categoryID,
            dueDate: dueDate,
            updatedAt: timestamp
        )
        tasks.append(task)
        persist()
        reminderScheduler.schedule(for: task)
    }

    func addCategory(named name: String) -> TaskCategory? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !categories.contains(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            return nil
        }

        let category = TaskCategory(name: cleaned)
        categories.append(category)
        persistCategories()
        return category
    }

    func deleteCategory(id: UUID) {
        guard id != TaskCategory.workID, id != TaskCategory.personalID else { return }

        categories.removeAll { $0.id == id }
        let timestamp = now()
        for index in tasks.indices where tasks[index].categoryID == id {
            tasks[index].categoryID = nil
            tasks[index].updatedAt = timestamp
        }
        persistCategories()
        persist()
    }

    func category(for id: UUID?) -> TaskCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
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
        let task = tasks[index]
        persist()
        task.isCompleted ? reminderScheduler.cancel(for: id) : reminderScheduler.schedule(for: task)
    }

    func updateCategory(id: UUID, categoryID: UUID?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].categoryID = categoryID
        tasks[index].updatedAt = now()
        persist()
    }

    func updateDueDate(id: UUID, dueDate: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].dueDate = dueDate
        tasks[index].updatedAt = now()
        let task = tasks[index]
        persist()
        dueDate == nil ? reminderScheduler.cancel(for: id) : reminderScheduler.schedule(for: task)
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        reminderScheduler.cancel(for: id)
        persist()
    }

    func clearHistory() {
        tasks.removeAll { $0.isCompleted }
        persist()
    }

    private func reload() {
        do {
            tasks = try repository.load()
            categories = try categoryRepository.load()
            tasks.filter { !$0.isCompleted && ($0.dueDate ?? .distantPast) > now() }
                .forEach(reminderScheduler.schedule)
        } catch {
            errorMessage = "Не удалось прочитать сохранённые дела."
        }
    }

    private func persistCategories() {
        do {
            try categoryRepository.save(categories)
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сохранить разделы."
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
