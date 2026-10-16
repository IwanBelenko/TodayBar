import SwiftUI

struct SearchEmptyView: View {
    @Binding var query: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(L10n.text("Ничего не найдено", "No results"))
                .font(.system(size: 16, weight: .medium))
            Text(L10n.text("Попробуйте другие слова\nили проверьте выбранный раздел", "Try different words\nor check the selected category"))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.text("Сбросить поиск", "Clear search")) { query = "" }
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
