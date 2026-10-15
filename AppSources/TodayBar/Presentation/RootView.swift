import SwiftUI

struct RootView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case history = "История"

        var id: Self { self }
    }

    @ObservedObject var model: TaskListViewModel
    let hoverChanged: (Bool) -> Void
    @State private var section: Section = .today
    @State private var searchQuery = ""
    @State private var selectedCategoryID: UUID?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            CategoryBar(model: model, selectedCategoryID: $selectedCategoryID)

            Group {
                switch section {
                case .today:
                    TodayView(model: model, searchQuery: $searchQuery, selectedCategoryID: $selectedCategoryID)
                case .history:
                    HistoryView(model: model, searchQuery: $searchQuery, selectedCategoryID: selectedCategoryID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.07))
            }

            footer
        }
        .frame(width: 420, height: 590)
        .background(TodayPalette.surface)
        .onHover(perform: hoverChanged)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 34)
                .background(TodayPalette.hover, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TodayPalette.line, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Сегодня")
                    .font(.system(size: 21, weight: .semibold))
                ViewThatFits(in: .horizontal) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .fixedSize()
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)))
                        .fixedSize()
                }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            searchField

            Menu {
                Button("Найти задачу") { isSearchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("Завершить Today") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Меню")
        }
        .padding(.horizontal, 19)
        .padding(.top, 18)
        .padding(.bottom, 13)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Поиск задач", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .accessibilityLabel("Поиск задач в выбранной вкладке")
                .onExitCommand {
                    if searchQuery.isEmpty { isSearchFocused = false }
                    else { searchQuery = "" }
                }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 138, height: 32)
        .background(TodayPalette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSearchFocused ? Color.primary.opacity(0.4) : TodayPalette.border, lineWidth: 0.7)
        }
        .help("Поиск по тексту задач · ⌘F")
    }

    private var tabs: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Section.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            section = item
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(item.rawValue)
                            if item == .today {
                                Text("\(pendingCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 15, weight: section == item ? .medium : .regular))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            if section == item {
                                Rectangle()
                                    .fill(Color.primary)
                                    .frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(section == item ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            progress
                .fixedSize()
        }
        .padding(.horizontal, 19)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }

    private var progress: some View {
        HStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TodayPalette.line)
                    Capsule()
                        .fill(TodayPalette.accent)
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(width: 42, height: 3)

            Text("\(completedCount) из \(todayTotal)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .animation(.easeInOut(duration: 0.18), value: progressValue)
    }

    private var todayTotal: Int {
        pendingCount + completedCount
    }

    private var categoryFilter: TaskFilter { TaskFilter(query: "", categoryID: selectedCategoryID) }
    private var pendingCount: Int { model.todayPending.filter(categoryFilter.matches).count }
    private var completedCount: Int { model.todayCompleted.filter(categoryFilter.matches).count }
    private var overdueCount: Int {
        model.todayPending.filter { categoryFilter.matches($0) && ($0.dueDate ?? .distantFuture) < Date() }.count
    }

    private var progressValue: CGFloat {
        guard todayTotal > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(todayTotal)
    }

    private var footer: some View {
        HStack {
            if overdueCount > 0 {
                Label("Просрочено: \(overdueCount)", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Label("На этом Mac", systemImage: "lock")
            }
            Spacer()
            Text("Today")
        }
        .font(.system(size: 13))
        .foregroundStyle(overdueCount > 0 ? Color.primary : Color.secondary)
        .padding(.horizontal, 17)
        .frame(height: 34)
        .overlay(alignment: .top) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }
}
