import SwiftUI

struct TaskRow: View {
    let task: TodoItem
    @ObservedObject var model: TaskListViewModel
    @State private var title: String
    @State private var editorHeight: CGFloat = 22
    @State private var isHovered = false

    init(task: TodoItem, model: TaskListViewModel) {
        self.task = task
        self.model = model
        _title = State(initialValue: task.title)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            completionButton

            VStack(alignment: .leading, spacing: 4) {
                if task.isCompleted {
                    Text(task.title)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .strikethrough(true, color: Color.secondary.opacity(0.9))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                        .transition(.opacity)
                        .contextMenu {
                            Button(L10n.text("Скопировать задачу", "Copy task")) {
                                TaskClipboard.copy(task.title)
                            }
                        }
                } else {
                    AutoGrowingTextEditor(
                        text: $title,
                        height: $editorHeight,
                        placeholder: L10n.text("Название дела", "Task title"),
                        minHeight: 22,
                        font: .systemFont(ofSize: 16),
                        offersCopyEntireText: true,
                        onCommandSubmit: finishEditing,
                        onFocusChange: { focused in
                            // Do not steal focus from search or another editor on blur.
                            if !focused { model.finishEditing(id: task.id) }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: editorHeight)
                    .onChange(of: title) { value in
                        model.updateTitle(id: task.id, title: value)
                    }
                }

                metadata
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TaskActionsMenu(task: task, model: model)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(minHeight: 38)
        .background(
            isHovered ? TodayPalette.hover : .clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
        .onChange(of: task.title) { value in
            if title != value { title = value }
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if model.category(for: task.categoryID) != nil || task.dueDate != nil || task.priority != .none {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    categoryAndPriority
                    deadline
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) {
                    categoryAndPriority
                    deadline
                }
            }
            .font(.system(size: 11.5))
        }
    }

    private var categoryAndPriority: some View {
        HStack(spacing: 8) {
            TaskPriorityIndicator(priority: task.priority)
            if let category = model.category(for: task.categoryID) {
                Label(category.displayName, systemImage: category.systemImage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var deadline: some View {
        if let dueDate = task.dueDate {
            TaskDueDateLabel(dueDate: dueDate, isCompleted: task.isCompleted)
                .help(L10n.text("Изменить срок можно в меню •••", "Change the due date in the ••• menu"))
        }
    }

    private var completionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                model.toggleCompleted(id: task.id)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(task.isCompleted ? TodayPalette.accent : .clear)
                Circle()
                    .stroke(task.isCompleted ? TodayPalette.accent : Color.secondary.opacity(0.75), lineWidth: 1.2)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel(task.isCompleted ? L10n.text("Вернуть в список", "Restore task") : L10n.text("Отметить выполненным", "Complete task"))
    }

    private func finishEditing() {
        model.finishEditing(id: task.id)
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

}
