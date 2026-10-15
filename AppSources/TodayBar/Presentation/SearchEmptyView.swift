import SwiftUI

struct SearchEmptyView: View {
    @Binding var query: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("Ничего не найдено")
                .font(.system(size: 16, weight: .medium))
            Text("Попробуйте другие слова\nили проверьте выбранный раздел")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Сбросить поиск") { query = "" }
                .buttonStyle(.plain)
                .font(.system(size: 13.5, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(TodayPalette.hover, in: Capsule())
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
    }
}
