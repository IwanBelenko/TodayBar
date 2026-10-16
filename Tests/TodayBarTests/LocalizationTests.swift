import Foundation
import Testing
@testable import TodayBar

struct LocalizationTests {
    @Test func languageFollowsThePrimarySystemLanguage() {
        for language in ["ru", "ru-RU", "ru_BY", "RU-kz"] { #expect(L10n.isRussian(language)) }
        for language in [nil, "en-US", "fr-FR", "uk-UA", "russian", ""] { #expect(!L10n.isRussian(language)) }
    }

    @Test func displayNamesDoNotChangeTheStorageContract() throws {
        let work = TaskCategory.defaults[0]
        let custom = TaskCategory(name: "Работа")
        let task = TodoItem(title: "Мой текст\nMy text", categoryID: work.id, priority: .high)
        #expect(work.displayName == (L10n.isRussian(L10n.language) ? "Работа" : "Work"))
        #expect(TaskCategory.defaults[1].displayName == L10n.text("Личное", "Personal"))
        #expect(custom.displayName == "Работа")
        #expect(TaskPriority.high.menuTitle == L10n.text("Высокий · 3 огонька", "High · 3 flames"))
        let encoder = JSONEncoder()
        let categoryData = try encoder.encode(work)
        let json = try #require(JSONSerialization.jsonObject(with: categoryData) as? [String: Any])
        #expect(json["name"] as? String == "Работа")
        #expect(json["displayName"] == nil)
        #expect(try JSONDecoder().decode(TaskCategory.self, from: categoryData) == work)
        #expect(try JSONDecoder().decode(TodoItem.self, from: encoder.encode(task)) == task)
    }

    @Test @MainActor func translatedSystemCategoryCannotBeDuplicated() {
        let model = TaskListViewModel(repository: MemoryTaskRepository(tasks: []),
                                      categoryRepository: MemoryCategoryRepository(), reminderScheduler: TestReminderScheduler())
        #expect(model.addCategory(named: TaskCategory.defaults[0].displayName) == nil)
        #expect(model.addCategory(named: "Работа") == nil)
    }
}
