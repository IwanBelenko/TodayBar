import SwiftUI

/// One selection shared by today's tasks, history, search and progress.
struct CategoryBar: View {
    @ObservedObject var model: TaskListViewModel
    @Binding var selectedCategoryID: UUID?
    @State private var showsNewCategory = false
    @State private var newCategoryName = ""
    @State private var categoryToDelete: TaskCategory?
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "Все", icon: "tray", id: nil)
                ForEach(model.categories) { category in
                    chip(title: category.name, icon: category.systemImage, id: category.id)
                        .contextMenu {
                            if category.id != TaskCategory.workID && category.id != TaskCategory.personalID {
                                Button("Удалить раздел", role: .destructive) {
                                    categoryToDelete = category
                                    showsDeleteConfirmation = true
                                }
                            }
                        }
                }
                Button { showsNewCategory = true } label: {
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
        .alert("Новый раздел", isPresented: $showsNewCategory) {
            TextField("Название", text: $newCategoryName)
            Button("Отмена", role: .cancel) { newCategoryName = "" }
            Button("Добавить") {
                if let category = model.addCategory(named: newCategoryName) { selectedCategoryID = category.id }
                newCategoryName = ""
            }
        } message: { Text("Например: Учёба, Дом или Покупки") }
        .alert("Удалить раздел?", isPresented: $showsDeleteConfirmation, presenting: categoryToDelete) { category in
            Button("Отмена", role: .cancel) { categoryToDelete = nil }
            Button("Удалить", role: .destructive) {
                model.deleteCategory(id: category.id)
                if selectedCategoryID == category.id { selectedCategoryID = nil }
                categoryToDelete = nil
            }
        } message: { category in Text("Задачи из «\(category.name)» останутся в списке без раздела.") }
    }

    private func chip(title: String, icon: String, id: UUID?) -> some View {
        let selected = selectedCategoryID == id
        return Button { selectedCategoryID = id } label: {
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
}
