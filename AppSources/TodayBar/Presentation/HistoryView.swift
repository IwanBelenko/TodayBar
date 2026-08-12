import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: TaskListViewModel
    @State private var confirmClear = false

    private var groups: [(Date, [TodoItem])] {
        let calendar = Calendar.autoupdatingCurrent
        let grouped = Dictionary(grouping: model.completedHistory) { task in
            calendar.startOfDay(for: task.completedAt ?? task.updatedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(groups, id: \.0) { date, tasks in
                            historySection(date: date, tasks: tasks)
                        }
                    }
                    .padding(.horizontal, 19)
                    .padding(.vertical, 16)
                }

                historyFooter
            }
        }
        .alert("Очистить историю?", isPresented: $confirmClear) {
            Button("Отмена", role: .cancel) {}
            Button("Очистить", role: .destructive) { model.clearHistory() }
        } message: {
            Text("Все выполненные дела будут удалены без возможности восстановления.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 21))
                .foregroundStyle(.secondary)
            Text("История пуста")
                .font(.system(size: 13, weight: .medium))
            Text("Завершённые дела сохранятся здесь")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func historySection(date: Date, tasks: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(historyDate(date))
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("\(tasks.count)")
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 7)
            .overlay(alignment: .bottom) {
                Rectangle().fill(TodayPalette.line).frame(height: 0.5)
            }

            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                HistoryRow(task: task)
                if index < tasks.count - 1 {
                    Rectangle()
                        .fill(TodayPalette.line)
                        .frame(height: 0.5)
                        .padding(.leading, 27)
                }
            }
        }
    }

    private var historyFooter: some View {
        HStack {
            Text("Всего выполнено: \(model.completedHistory.count)")
                .monospacedDigit()
            Spacer()
            Button("Очистить") { confirmClear = true }
                .buttonStyle(.plain)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 17)
        .frame(height: 36)
        .overlay(alignment: .top) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }

    private func historyDate(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}

private struct HistoryRow: View {
    let task: TodoItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(TodayPalette.accent, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(.top, 1)

            Text(task.title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .strikethrough(true, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let date = task.completedAt {
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 9)
    }
}
