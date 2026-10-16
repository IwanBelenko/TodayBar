import SwiftUI

struct TaskPriorityIndicator: View {
    let priority: TaskPriority

    var body: some View {
        if priority != .none {
            HStack(spacing: 2) {
                ForEach(0..<priority.flameCount, id: \.self) { _ in
                    Image(systemName: "flame.fill")
                }
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("Приоритет: \(priority.title)", "Priority: \(priority.title)"))
            .help(L10n.text("Приоритет: \(priority.title)", "Priority: \(priority.title)"))
        }
    }
}
