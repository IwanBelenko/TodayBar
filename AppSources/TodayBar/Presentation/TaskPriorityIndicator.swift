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
            .accessibilityLabel("Приоритет: \(priority.title)")
            .help("Приоритет: \(priority.title)")
        }
    }
}
