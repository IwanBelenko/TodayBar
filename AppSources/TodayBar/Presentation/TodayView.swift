import SwiftUI

struct TodayView: View {
    @ObservedObject var model: TaskListViewModel
    @State private var newTask = ""
    @State private var composerHeight: CGFloat = 38
    @State private var isComposerFocused = false
    @State private var showsCompleted = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.todayPending.isEmpty && model.todayCompleted.isEmpty {
                        EmptyTodayView()
                            .padding(.top, 72)
                    } else {
                        ForEach(model.todayPending) { task in
                            TaskRow(task: task, model: model)
                                .id(taskRowID(for: task))
                        }

                        if !model.todayCompleted.isEmpty {
                            completedToggle
                                .padding(.top, 8)

                            if showsCompleted {
                                ForEach(model.todayCompleted) { task in
                                    TaskRow(task: task, model: model)
                                        .id(taskRowID(for: task))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .animation(.easeInOut(duration: 0.18), value: model.todayPending.map(\.id))
                .animation(.easeInOut(duration: 0.18), value: model.todayCompleted.map(\.id))
            }

            composer
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
                Text("Выполнено")
                Spacer()
                Text("\(model.todayCompleted.count)")
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
        VStack(alignment: .trailing, spacing: 5) {
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
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(TodayPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isComposerFocused ? TodayPalette.accent.opacity(0.65) : TodayPalette.border, lineWidth: 0.7)
            }

            Text("Enter — новая строка · ⌘↵ — добавить")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 11)
    }

    private func addTask() {
        let cleaned = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        model.add(title: cleaned)
        newTask = ""
        composerHeight = 38
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
