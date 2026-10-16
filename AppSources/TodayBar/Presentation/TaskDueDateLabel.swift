import SwiftUI

struct TaskDueDateLabel: View {
    let dueDate: Date
    let isCompleted: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let overdue = !isCompleted && dueDate < context.date
            Label(overdue ? L10n.text("Просрочено · \(formattedDate)", "Overdue · \(formattedDate)") : formattedDate, systemImage: overdue ? "exclamationmark.circle.fill" : "clock")
                .foregroundStyle(overdue ? Color.red : Color.secondary)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(dueDate) {
            return L10n.text("Сегодня", "Today") + ", " + dueDate.formatted(.dateTime.hour().minute().locale(L10n.locale))
        }
        if calendar.isDateInTomorrow(dueDate) {
            return L10n.text("Завтра", "Tomorrow") + ", " + dueDate.formatted(.dateTime.hour().minute().locale(L10n.locale))
        }
        return dueDate.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(L10n.locale))
    }
}
