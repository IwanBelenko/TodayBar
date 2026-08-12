import Foundation

@MainActor
protocol ReminderScheduling {
    func schedule(for task: TodoItem)
    func cancel(for taskID: UUID)
}
