import SwiftUI

struct TaskRow: View {
    let task: TodoItem
    @ObservedObject var model: TaskListViewModel
    @State private var title: String
    @State private var editorHeight: CGFloat = 22
    @State private var isHovered = false
    @State private var isEditing = false

    init(task: TodoItem, model: TaskListViewModel) {
        self.task = task
        self.model = model
        _title = State(initialValue: task.title)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            completionButton

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
                        Button("Скопировать задачу") {
                            TaskClipboard.copy(task.title)
                        }
                    }
            } else {
                AutoGrowingTextEditor(
                    text: $title,
                    height: $editorHeight,
                    placeholder: "Название дела",
                    minHeight: 22,
                    font: .systemFont(ofSize: 16),
                    offersCopyEntireText: true,
                    onCommandSubmit: finishEditing,
                    onFocusChange: { focused in
                        isEditing = focused
                        if !focused { finishEditing() }
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: editorHeight)
                .onChange(of: title) { value in
                    model.updateTitle(id: task.id, title: value)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    model.delete(id: task.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isEditing ? 1 : 0)
            .accessibilityLabel("Удалить")
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
        .accessibilityLabel(task.isCompleted ? "Вернуть в список" : "Отметить выполненным")
    }

    private func finishEditing() {
        model.finishEditing(id: task.id)
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
