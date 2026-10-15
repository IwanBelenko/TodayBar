import Foundation
import Testing
@testable import TodayBar

struct TaskTests {
    private let legacyTask = """
    {"id":"4BBAFC99-8F25-4664-8F21-EC2B178FEA30","title":"Старая задача\\nс абзацем",
     "createdAt":"2026-08-12T09:00:00Z","scheduledFor":"2026-08-12T09:00:00Z",
     "updatedAt":"2026-08-12T09:00:00Z"}
    """

    @Test func legacyTasksLoadWithoutPriority() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(TodoItem.self, from: Data(legacyTask.utf8))
        #expect(task.priority == .none)
        #expect(task.title == "Старая задача\nс абзацем")
        #expect(task.dueDate == nil)
        #expect(!task.isCompleted)
    }

    @Test func unknownPriorityDoesNotMakeTaskFileUnreadable() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = legacyTask.replacingOccurrences(of: "{", with: "{\"priority\":\"future-level\",")
        #expect(try decoder.decode(TodoItem.self, from: Data(json.utf8)).priority == .none)
    }

    @Test func everyPrioritySurvivesEncodingAndDecoding() throws {
        let date = Date(timeIntervalSince1970: 1_786_532_400)
        for priority in TaskPriority.allCases {
            let task = TodoItem(title: "Текст\nполностью", createdAt: date, scheduledFor: date,
                                categoryID: TaskCategory.workID, dueDate: date,
                                completedAt: date, updatedAt: date, priority: priority)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            #expect(try decoder.decode(TodoItem.self, from: encoder.encode(task)) == task)
        }
    }

    @Test func searchIgnoresCaseDiacriticsAndExtraWhitespace() {
        let task = TodoItem(title: "Обсудить отчёт\nс Машей")
        #expect(TaskFilter(query: "  МАШЕЙ  отчет\n").matches(task))
        #expect(TaskFilter(query: "ОБСУДИТЬ").matches(task))
        #expect(!TaskFilter(query: "отчет завтра").matches(task))
        #expect(!TaskFilter(query: "несуществующий текст").matches(task))
    }

    @Test func emptySearchAndCategoryComposeWithoutChangingTask() {
        let task = TodoItem(title: "Задача", categoryID: TaskCategory.workID)
        #expect(!TaskFilter(query: " \n\t").isSearching)
        #expect(TaskFilter(query: "").matches(task))
        #expect(TaskFilter(query: "зада", categoryID: TaskCategory.workID).matches(task))
        #expect(!TaskFilter(query: "зада", categoryID: TaskCategory.personalID).matches(task))
    }

    @Test @MainActor
    func priorityPersistsAndReordersWithoutChangingReminders() throws {
        let first = TodoItem(title: "Первая", createdAt: Date(timeIntervalSince1970: 100))
        let second = TodoItem(title: "Вторая", createdAt: Date(timeIntervalSince1970: 200))
        let repository = MemoryTaskRepository(tasks: [first, second])
        let scheduler = TestReminderScheduler()
        let timestamp = Date(timeIntervalSince1970: 300)
        let model = TaskListViewModel(repository: repository, categoryRepository: MemoryCategoryRepository(),
                                      reminderScheduler: scheduler, now: { timestamp })
        model.updatePriority(id: second.id, priority: .high)
        #expect(model.todayPending.map(\.id) == [second.id, first.id])
        #expect(repository.tasks[1].priority == .high)
        #expect(repository.tasks[1].updatedAt == timestamp)
        #expect(scheduler.scheduled.isEmpty)
        #expect(scheduler.cancelled.isEmpty)
        let reloaded = TaskListViewModel(repository: repository, categoryRepository: MemoryCategoryRepository(),
                                         reminderScheduler: scheduler, now: { timestamp })
        #expect(reloaded.tasks[1].priority == .high)
        #expect(reloaded.todayPending.map(\.id) == [second.id, first.id])
        reloaded.toggleCompleted(id: second.id)
        #expect(reloaded.todayCompleted.first?.priority == .high)
        reloaded.updatePriority(id: second.id, priority: .none)
        #expect(repository.tasks[1].priority == .none)
        reloaded.toggleCompleted(id: second.id)
        #expect(reloaded.todayPending.map(\.id) == [first.id, second.id])
    }

    @Test @MainActor
    func pendingTasksSortByFlamesThenAgeWithSearchAndCategoryFilters() {
        let levels: [TaskPriority] = [.none, .low, .medium, .high, .high, .high]
        let tasks = levels.enumerated().map { index, priority in
            TodoItem(title: "Отчёт \(index)", createdAt: Date(timeIntervalSince1970: Double(index)),
                     categoryID: index == 4 ? TaskCategory.personalID : TaskCategory.workID,
                     priority: priority)
        }
        let repository = MemoryTaskRepository(tasks: [tasks[0], tasks[5], tasks[2], tasks[1], tasks[3], tasks[4]])
        let model = TaskListViewModel(repository: repository, categoryRepository: MemoryCategoryRepository(),
                                      reminderScheduler: TestReminderScheduler())
        #expect(model.todayPending.map(\.id) == [3, 4, 5, 2, 1, 0].map { tasks[$0].id })
        let filter = TaskFilter(query: "отчет", categoryID: TaskCategory.workID)
        #expect(model.todayPending.filter(filter.matches).map(\.id) == [3, 5, 2, 1, 0].map { tasks[$0].id })

        model.updatePriority(id: tasks[2].id, priority: .high)
        #expect(model.todayPending.map(\.id) == [2, 3, 4, 5, 1, 0].map { tasks[$0].id })
        model.updatePriority(id: tasks[5].id, priority: .none)
        #expect(model.todayPending.map(\.id) == [2, 3, 4, 1, 0, 5].map { tasks[$0].id })
        #expect(repository.tasks.map(\.id) == [0, 5, 2, 1, 3, 4].map { tasks[$0].id })
    }

    @Test @MainActor
    func completedTasksSortWithinTheirDayWithoutMixingHistoryDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let tasks = [
            TodoItem(title: "Сегодня без приоритета", completedAt: now, priority: .none),
            TodoItem(title: "Сегодня высокий старше", completedAt: now.addingTimeInterval(-7200), priority: .high),
            TodoItem(title: "Вчера высокий", completedAt: now.addingTimeInterval(-86400), priority: .high),
            TodoItem(title: "Сегодня низкий", completedAt: now.addingTimeInterval(-1800), priority: .low),
            TodoItem(title: "Сегодня высокий новее", completedAt: now.addingTimeInterval(-3600), priority: .high)
        ]
        let model = TaskListViewModel(repository: MemoryTaskRepository(tasks: tasks),
                                      categoryRepository: MemoryCategoryRepository(),
                                      reminderScheduler: TestReminderScheduler(), calendar: calendar, now: { now })
        #expect(model.todayPending.isEmpty)
        #expect(model.todayCompleted.map(\.id) == [4, 1, 3, 0].map { tasks[$0].id })
        #expect(model.completedHistory.map(\.id) == [4, 1, 3, 0, 2].map { tasks[$0].id })
        model.updatePriority(id: tasks[0].id, priority: .high)
        #expect(model.todayCompleted.map(\.id) == [0, 4, 1, 3].map { tasks[$0].id })
        #expect(model.completedHistory.map(\.id) == [0, 4, 1, 3, 2].map { tasks[$0].id })
    }

    @Test @MainActor
    func historyAndCountsFollowSelectedCategoryWithoutClearingOtherSections() {
        let family = UUID()
        let now = Date()
        let tasks = [
            TodoItem(title: "Отчёт рабочий", categoryID: TaskCategory.workID, completedAt: now),
            TodoItem(title: "Отчёт личный", categoryID: TaskCategory.personalID, completedAt: now),
            TodoItem(title: "Отчёт семейный", categoryID: family, completedAt: now),
            TodoItem(title: "Рабочая задача", categoryID: TaskCategory.workID),
            TodoItem(title: "Без раздела", completedAt: now)
        ]
        let model = TaskListViewModel(repository: MemoryTaskRepository(tasks: tasks),
                                      categoryRepository: MemoryCategoryRepository(), reminderScheduler: TestReminderScheduler())
        for categoryID in [TaskCategory.workID, TaskCategory.personalID, family] {
            let filter = TaskFilter(query: "отчет", categoryID: categoryID)
            #expect(model.completedHistory.filter(filter.matches).count == 1)
            #expect(model.todayCompleted.filter(filter.matches).count == 1)
        }
        #expect(model.completedHistory.filter(TaskFilter(query: "").matches).count == 4)
        model.clearHistory(categoryID: TaskCategory.workID)
        #expect(model.tasks.map(\.id) == [1, 2, 3, 4].map { tasks[$0].id })
        #expect(model.todayPending.map(\.id) == [tasks[3].id])
        model.clearHistory()
        #expect(model.tasks.map(\.id) == [tasks[3].id])
    }

    @Test @MainActor
    func jsonRepositoryRoundTripWithPriorities() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONTaskRepository(fileURL: directory.appendingPathComponent("tasks.json"))
        let tasks = TaskPriority.allCases.map { TodoItem(title: $0.title, priority: $0) }
        try repository.save(tasks)
        let reloaded = try repository.load()
        #expect(reloaded.map(\.id) == tasks.map(\.id))
        #expect(reloaded.map(\.priority) == TaskPriority.allCases)
        #expect(reloaded.map(\.title) == tasks.map(\.title))
    }
}

@MainActor
final class MemoryTaskRepository: TaskRepository {
    var tasks: [TodoItem]
    init(tasks: [TodoItem] = []) { self.tasks = tasks }
    func load() throws -> [TodoItem] { tasks }
    func save(_ tasks: [TodoItem]) throws { self.tasks = tasks }
}

@MainActor
final class MemoryCategoryRepository: CategoryRepository {
    var categories = TaskCategory.defaults
    func load() throws -> [TaskCategory] { categories }
    func save(_ categories: [TaskCategory]) throws { self.categories = categories }
}

@MainActor
final class TestReminderScheduler: ReminderScheduling {
    var scheduled: [UUID] = []
    var cancelled: [UUID] = []
    func schedule(for task: TodoItem) { scheduled.append(task.id) }
    func cancel(for taskID: UUID) { cancelled.append(taskID) }
}
