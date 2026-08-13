import SwiftUI

struct TodayView: View {
    @ObservedObject var model: TaskListViewModel
    @State private var newTask = ""
    @State private var composerHeight: CGFloat = 38
    @State private var isComposerFocused = false
    @State private var showsCompleted = true
    @State private var selectedCategoryID: UUID?
    @State private var composerCategoryID: UUID? = TaskCategory.personalID
    @State private var dueDate: Date?
    @State private var showsDeadlinePicker = false
    @State private var showsNewCategory = false
    @State private var newCategoryName = ""
    @State private var categoryToDelete: TaskCategory?
    @State private var showsDeleteCategoryConfirmation = false

    private var pendingTasks: [TodoItem] {
        model.todayPending.filter { selectedCategoryID == nil || $0.categoryID == selectedCategoryID }
    }

    private var completedTasks: [TodoItem] {
        model.todayCompleted.filter { selectedCategoryID == nil || $0.categoryID == selectedCategoryID }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryBar

            ScrollView {
                LazyVStack(spacing: 0) {
                    if pendingTasks.isEmpty && completedTasks.isEmpty {
                        EmptyTodayView()
                            .padding(.top, 72)
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
        .alert("Новый раздел", isPresented: $showsNewCategory) {
            TextField("Название", text: $newCategoryName)
            Button("Отмена", role: .cancel) { newCategoryName = "" }
            Button("Добавить") { addCategory() }
        } message: {
            Text("Например: Учёба, Дом или Покупки")
        }
        .alert("Удалить раздел?", isPresented: $showsDeleteCategoryConfirmation, presenting: categoryToDelete) { category in
            Button("Отмена", role: .cancel) { categoryToDelete = nil }
            Button("Удалить", role: .destructive) { deleteCategory(category) }
        } message: { category in
            Text("Задачи из «\(category.name)» останутся в списке без раздела.")
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip(title: "Все", icon: "tray", id: nil)

                ForEach(model.categories) { category in
                    categoryChip(title: category.name, icon: category.systemImage, id: category.id)
                        .contextMenu {
                            if category.id != TaskCategory.workID && category.id != TaskCategory.personalID {
                                Button("Удалить раздел", role: .destructive) {
                                    categoryToDelete = category
                                    showsDeleteCategoryConfirmation = true
                                }
                            }
                        }
                }

                Button {
                    showsNewCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 27, height: 27)
                        .background(TodayPalette.hover, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Новый раздел")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }

    private func categoryChip(title: String, icon: String, id: UUID?) -> some View {
        let selected = selectedCategoryID == id
        return Button {
            selectedCategoryID = id
            if let id { composerCategoryID = id }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                .padding(.horizontal, 10)
                .frame(height: 27)
                .background(selected ? TodayPalette.hover : Color.clear, in: Capsule())
                .overlay {
                    Capsule().stroke(selected ? TodayPalette.border : Color.clear, lineWidth: 0.6)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? .primary : .secondary)
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
                Text("Выполнено")
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
        .accessibilityLabel(showsCompleted ? "Скрыть выполненные" : "Показать выполненные")
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
                    placeholder: "Новое дело…",
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
                .accessibilityLabel("Добавить дело")
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
                    Button("Без раздела") { composerCategoryID = nil }
                    Divider()
                    ForEach(model.categories) { category in
                        Button(category.name) { composerCategoryID = category.id }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.category(for: composerCategoryID)?.systemImage ?? "tray")
                        Text(model.category(for: composerCategoryID)?.name ?? "Без раздела")
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
                            Label("Срок", systemImage: "calendar.badge.plus")
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

                Text("↵ добавить  ·  ⇧↵ строка")
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
    }

    private func addCategory() {
        if let category = model.addCategory(named: newCategoryName) {
            selectedCategoryID = category.id
            composerCategoryID = category.id
        }
        newCategoryName = ""
    }

    private func deleteCategory(_ category: TaskCategory) {
        model.deleteCategory(id: category.id)
        if selectedCategoryID == category.id { selectedCategoryID = nil }
        if composerCategoryID == category.id { composerCategoryID = nil }
        categoryToDelete = nil
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
            Text("На сегодня дел нет")
                .font(.system(size: 16, weight: .medium))
            Text("Добавьте первое дело ниже")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
