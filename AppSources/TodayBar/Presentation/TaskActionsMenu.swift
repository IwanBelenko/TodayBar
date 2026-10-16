import SwiftUI

/// Shared actions for current tasks and history, with one visible entry point.
struct TaskActionsMenu: View {
    let task: TodoItem
    @ObservedObject var model: TaskListViewModel
    @State private var showsDeadlinePicker = false

    var body: some View {
        Menu {
            Menu {
                Picker(L10n.text("Приоритет", "Priority"), selection: Binding(
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
                Label(L10n.text("Приоритет", "Priority"), systemImage: "flame")
            }

            if !task.isCompleted {
                Button {
                    DispatchQueue.main.async { showsDeadlinePicker = true }
                } label: {
                    Label(task.dueDate == nil ? L10n.text("Добавить срок…", "Add due date…") : L10n.text("Изменить срок…", "Change due date…"), systemImage: "calendar")
                }
                if task.dueDate != nil {
                    Button(L10n.text("Убрать срок", "Remove due date")) { model.updateDueDate(id: task.id, dueDate: nil) }
                }
            }

            Menu {
                Picker(L10n.text("Раздел", "Category"), selection: Binding(
                    get: { task.categoryID },
                    set: { model.updateCategory(id: task.id, categoryID: $0) }
                )) {
                    Text(L10n.text("Без раздела", "No category")).tag(nil as UUID?)
                    ForEach(model.categories) { category in
                        Label(category.displayName, systemImage: category.systemImage)
                            .tag(Optional(category.id))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(L10n.text("Раздел", "Category"), systemImage: "folder")
            }

            Divider()

            Button {
                TaskClipboard.copy(task.title)
            } label: {
                Label(L10n.text("Скопировать задачу", "Copy task"), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    model.delete(id: task.id)
                }
            } label: {
                Label(L10n.text("Удалить задачу", "Delete task"), systemImage: "trash")
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
        .help(L10n.text("Действия задачи", "Task actions"))
        .accessibilityLabel(L10n.text("Действия задачи «\(task.title)»", "Actions for “\(task.title)”"))
        .popover(isPresented: $showsDeadlinePicker, arrowEdge: .trailing) {
            DeadlinePickerView(dueDate: Binding(
                get: { task.dueDate },
                set: { model.updateDueDate(id: task.id, dueDate: $0) }
            ))
        }
    }
}
