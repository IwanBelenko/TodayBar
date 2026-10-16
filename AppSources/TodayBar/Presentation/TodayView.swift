import SwiftUI

struct TodayView: View {
    @ObservedObject var model: TaskListViewModel
    @Binding var searchQuery: String
    @Binding var selectedCategoryID: UUID?
    @State private var newTask = ""
    @State private var composerHeight: CGFloat = 38
    @State private var isComposerFocused = false
    @State private var showsCompleted = true
    @State private var composerCategoryID: UUID? = TaskCategory.personalID
    @State private var dueDate: Date?
    @State private var showsDeadlinePicker = false

    private var pendingTasks: [TodoItem] {
        model.todayPending.filter(taskFilter.matches)
    }

    private var completedTasks: [TodoItem] {
        model.todayCompleted.filter(taskFilter.matches)
    }

    private var taskFilter: TaskFilter {
        TaskFilter(query: searchQuery, categoryID: selectedCategoryID)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if pendingTasks.isEmpty && completedTasks.isEmpty {
                        if taskFilter.isSearching {
                            SearchEmptyView(query: $searchQuery)
                                .padding(.top, 48)
                        } else {
                            EmptyTodayView()
                                .padding(.top, 72)
                        }
                    } else {
                        ForEach(pendingTasks) { task in
                            TaskRow(task: task, model: model)
                                .id(taskRowID(for: task))
                        }

                        if !completedTasks.isEmpty {
                            completedToggle
                                .padding(.top, 8)

                            if showsCompleted {
                                ForEach(completedTasks) { task in
                                    TaskRow(task: task, model: model)
                                        .id(taskRowID(for: task))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .animation(.easeInOut(duration: 0.18), value: pendingTasks.map(\.id))
                .animation(.easeInOut(duration: 0.18), value: completedTasks.map(\.id))
            }

            composer
        }
        .onChange(of: searchQuery) { _ in
            if taskFilter.isSearching { showsCompleted = true }
        }
        .onAppear {
            if let selectedCategoryID { composerCategoryID = selectedCategoryID }
        }
        .onChange(of: selectedCategoryID) { id in
            if let id { composerCategoryID = id }
        }
        .onChange(of: model.categories) { _ in
            if composerCategoryID != nil && model.category(for: composerCategoryID) == nil {
                composerCategoryID = nil
            }
        }
    }

    private var completedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showsCompleted.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .rotationEffect(.degrees(showsCompleted ? 0 : -90))
                Text(L10n.text("Выполнено", "Completed"))
                Spacer()
                Text("\(completedTasks.count)")
                    .monospacedDigit()
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsCompleted ? L10n.text("Скрыть выполненные", "Hide completed") : L10n.text("Показать выполненные", "Show completed"))
    }

    private var composer: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                AutoGrowingTextEditor(
                    text: $newTask,
                    height: $composerHeight,
                    placeholder: L10n.text("Новое дело…", "New task…"),
                    minHeight: 38,
                    maxHeight: 112,
                    font: .systemFont(ofSize: 16),
                    onCommandSubmit: addTask,
                    onFocusChange: { isComposerFocused = $0 }
                )
                .frame(maxWidth: .infinity)
                .frame(height: composerHeight)

                Button(action: addTask) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TodayPalette.actionForeground)
                        .frame(width: 23, height: 23)
                        .background(TodayPalette.actionFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 1)
                .accessibilityLabel(L10n.text("Добавить дело", "Add task"))
            }
            .padding(.horizontal, 13)
            .padding(.top, 11)
            .padding(.bottom, 8)

            Rectangle()
                .fill(TodayPalette.line)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            HStack(spacing: 7) {
                Menu {
                    Button(L10n.text("Без раздела", "No category")) { composerCategoryID = nil }
                    Divider()
                    ForEach(model.categories) { category in
                        Button(category.displayName) { composerCategoryID = category.id }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.category(for: composerCategoryID)?.systemImage ?? "tray")
                        Text(model.category(for: composerCategoryID)?.displayName ?? L10n.text("Без раздела", "No category"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .frame(maxWidth: 102, minHeight: 28)
                    .background(TodayPalette.hover, in: Capsule())
                    .contentShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Button {
                    showsDeadlinePicker = true
                } label: {
                    HStack(spacing: 5) {
                        if let dueDate {
                            TaskDueDateLabel(dueDate: dueDate, isCompleted: false)
                        } else {
                            Label(L10n.text("Срок", "Due date"), systemImage: "calendar.badge.plus")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(maxWidth: 112, minHeight: 28)
                    .background(TodayPalette.hover, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsDeadlinePicker, arrowEdge: .bottom) {
                    DeadlinePickerView(dueDate: $dueDate)
                }

                Spacer()

                Text(L10n.text("↵ добавить  ·  ⇧↵ строка", "↵ add  ·  ⇧↵ new line"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            .font(.system(size: 11.5))
            .padding(.horizontal, 12)
            .frame(height: 42)
        }
        .background(TodayPalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isComposerFocused ? TodayPalette.accent.opacity(0.65) : TodayPalette.border, lineWidth: 0.7)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 15)
    }

    private func addTask() {
        let cleaned = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        model.add(title: cleaned, categoryID: composerCategoryID, dueDate: dueDate)
        newTask = ""
        dueDate = nil
        composerHeight = 38
        searchQuery = ""
    }

    private func taskRowID(for task: TodoItem) -> String {
        "\(task.id.uuidString)-\(task.isCompleted ? "completed" : "pending")"
    }
}

private struct EmptyTodayView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.secondary)
            Text(L10n.text("На сегодня дел нет", "No tasks for today"))
                .font(.system(size: 16, weight: .medium))
            Text(L10n.text("Добавьте первое дело ниже", "Add your first task below"))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
