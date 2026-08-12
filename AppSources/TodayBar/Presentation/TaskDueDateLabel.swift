import SwiftUI

struct TaskDueDateLabel: View {
    let dueDate: Date
    let isCompleted: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let overdue = !isCompleted && dueDate < context.date
            Label(overdue ? "Просрочено · \(formattedDate)" : formattedDate, systemImage: overdue ? "exclamationmark.circle.fill" : "clock")
                .foregroundStyle(overdue ? Color.red : Color.secondary)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(dueDate) {
            return "Сегодня, \(dueDate.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Завтра, \(dueDate.formatted(date: .omitted, time: .shortened))"
        }
        return dueDate.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
