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

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs

            Group {
                switch section {
                case .today:
                    TodayView(model: model)
                case .history:
                    HistoryView(model: model)
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
        .frame(width: 400, height: 548)
        .background(TodayPalette.surface)
        .onHover(perform: hoverChanged)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 34)
                .background(TodayPalette.hover, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TodayPalette.line, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Сегодня")
                    .font(.system(size: 18, weight: .semibold))
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Завершить Today") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
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

    private var tabs: some View {
        HStack(spacing: 20) {
            ForEach(Section.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        section = item
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(item.rawValue)
                        if item == .today {
                            Text("\(model.todayPending.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 13.5, weight: section == item ? .medium : .regular))
                    .frame(height: 34)
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
            }

            Spacer()
            progress
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

            Text("\(model.todayCompleted.count) из \(todayTotal)")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .animation(.easeInOut(duration: 0.18), value: progressValue)
    }

    private var todayTotal: Int {
        model.todayPending.count + model.todayCompleted.count
    }

    private var progressValue: CGFloat {
        guard todayTotal > 0 else { return 0 }
        return CGFloat(model.todayCompleted.count) / CGFloat(todayTotal)
    }

    private var footer: some View {
        HStack {
            Label("На этом Mac", systemImage: "lock")
            Spacer()
            Text("Today")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 17)
        .frame(height: 34)
        .overlay(alignment: .top) {
            Rectangle().fill(TodayPalette.line).frame(height: 0.5)
        }
    }
}
