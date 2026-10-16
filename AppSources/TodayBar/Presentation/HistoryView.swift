import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: TaskListViewModel
    @Binding var searchQuery: String
    let selectedCategoryID: UUID?
    @State private var confirmClear = false

    private var taskFilter: TaskFilter { TaskFilter(query: searchQuery, categoryID: selectedCategoryID) }

    private var matchingTasks: [TodoItem] {
        model.completedHistory.filter(taskFilter.matches)
    }

    private var groups: [(Date, [TodoItem])] {
        let calendar = Calendar.autoupdatingCurrent
        let grouped = Dictionary(grouping: matchingTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.updatedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                if taskFilter.isSearching {
                    SearchEmptyView(query: $searchQuery)
                        .frame(maxHeight: .infinity)
                } else {
                    emptyState
                }
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
        .alert(L10n.text("Очистить историю?", "Clear history?"), isPresented: $confirmClear) {
            Button(L10n.text("Отмена", "Cancel"), role: .cancel) {}
            Button(L10n.text("Очистить", "Clear"), role: .destructive) { model.clearHistory(categoryID: selectedCategoryID) }
        } message: {
            let categoryName = model.category(for: selectedCategoryID)?.displayName ?? ""
            Text(selectedCategoryID == nil
                 ? L10n.text("Все выполненные дела будут удалены без возможности восстановления.", "All completed tasks will be permanently deleted.")
                 : L10n.text("Выполненные дела из раздела «\(categoryName)» будут удалены. История остальных разделов сохранится.", "Completed tasks in “\(categoryName)” will be deleted. Other categories will keep their history."))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 21))
                .foregroundStyle(.secondary)
            Text(L10n.text("История пуста", "History is empty"))
                .font(.system(size: 16, weight: .medium))
            Text(L10n.text("Завершённые дела сохранятся здесь", "Completed tasks will appear here"))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func historySection(date: Date, tasks: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(historyDate(date))
                    .font(.system(size: 14, weight: .medium))
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
                HistoryRow(task: task, model: model)
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
            Text(taskFilter.isSearching ? L10n.text("Найдено: \(matchingTasks.count)", "Found: \(matchingTasks.count)") : L10n.text("Всего выполнено: \(matchingTasks.count)", "Total completed: \(matchingTasks.count)"))
                .monospacedDigit()
            Spacer()
            if !taskFilter.isSearching {
                Button(L10n.text("Очистить", "Clear")) { confirmClear = true }
                    .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 17)
        .frame(height: 36)
        .overlay(alignment: .top) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }

    private func historyDate(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) { return L10n.text("Сегодня", "Today") }
        if calendar.isDateInYesterday(date) { return L10n.text("Вчера", "Yesterday") }
        return date.formatted(.dateTime.day().month(.wide).year().locale(L10n.locale))
    }
}

private struct HistoryRow: View {
    let task: TodoItem
    @ObservedObject var model: TaskListViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(TodayPalette.accent, in: Circle())
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.secondary)
                    .strikethrough(true, color: Color.secondary.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contextMenu {
                        Button(L10n.text("Скопировать задачу", "Copy task")) {
                            TaskClipboard.copy(task.title)
                        }
                    }

                HStack(spacing: 8) {
                    TaskPriorityIndicator(priority: task.priority)
                    if let category = model.category(for: task.categoryID) {
                        Label(category.displayName, systemImage: category.systemImage)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let date = task.completedAt {
                Text(date.formatted(.dateTime.hour().minute().locale(L10n.locale)))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            TaskActionsMenu(task: task, model: model)
        }
        .padding(.vertical, 9)
    }
}
