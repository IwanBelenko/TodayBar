import SwiftUI

/// Shared actions for current tasks and history, with one visible entry point.
struct TaskActionsMenu: View {
    let task: TodoItem
    @ObservedObject var model: TaskListViewModel
    @State private var showsDeadlinePicker = false

    var body: some View {
        Menu {
            Menu {
                Picker("Приоритет", selection: Binding(
                    get: { task.priority },
                    set: { model.updatePriority(id: task.id, priority: $0) }
                )) {
                    ForEach(TaskPriority.allCases) { priority in
                        Label(priority.menuTitle, systemImage: priority == .none ? "minus" : "flame.fill")
                            .tag(priority)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Приоритет", systemImage: "flame")
            }

            if !task.isCompleted {
                Button {
                    DispatchQueue.main.async { showsDeadlinePicker = true }
                } label: {
                    Label(task.dueDate == nil ? "Добавить срок…" : "Изменить срок…", systemImage: "calendar")
                }
                if task.dueDate != nil {
                    Button("Убрать срок") { model.updateDueDate(id: task.id, dueDate: nil) }
                }
            }

            Menu {
                Picker("Раздел", selection: Binding(
                    get: { task.categoryID },
                    set: { model.updateCategory(id: task.id, categoryID: $0) }
                )) {
                    Text("Без раздела").tag(nil as UUID?)
                    ForEach(model.categories) { category in
                        Label(category.name, systemImage: category.systemImage)
                            .tag(Optional(category.id))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Раздел", systemImage: "folder")
            }

            Divider()

            Button {
                TaskClipboard.copy(task.title)
            } label: {
                Label("Скопировать задачу", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    model.delete(id: task.id)
                }
            } label: {
                Label("Удалить задачу", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Действия задачи")
        .accessibilityLabel("Действия задачи «\(task.title)»")
        .popover(isPresented: $showsDeadlinePicker, arrowEdge: .trailing) {
            DeadlinePickerView(dueDate: Binding(
                get: { task.dueDate },
                set: { model.updateDueDate(id: task.id, dueDate: $0) }
            ))
        }
    }
}
