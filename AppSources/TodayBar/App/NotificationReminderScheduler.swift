import Foundation
@preconcurrency import UserNotifications

@MainActor
final class NotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(for task: TodoItem) {
        guard !task.isCompleted, let dueDate = task.dueDate, dueDate > Date() else {
            cancel(for: task.id)
            return
        }

        let identifier = notificationID(for: task.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        center.requestAuthorization(options: [.alert, .sound]) { [center] granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Срок задачи наступил"
            content.body = task.title
            content.sound = .default

            let components = Calendar.autoupdatingCurrent.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    func cancel(for taskID: UUID) {
        let identifier = notificationID(for: taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func notificationID(for taskID: UUID) -> String {
        "today.task.\(taskID.uuidString)"
    }
}
