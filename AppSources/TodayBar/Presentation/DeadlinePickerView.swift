import Foundation
import SwiftUI

struct DeadlinePickerView: View {
    private enum TimeField: Hashable {
        case hour
        case minute
    }

    @Binding var dueDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date
    @State private var displayedMonth: Date
    @State private var hourText: String
    @State private var minuteText: String
    @FocusState private var focusedTimeField: TimeField?

    private let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    init(dueDate: Binding<Date?>) {
        let initialDate = dueDate.wrappedValue ?? Self.defaultDate()
        _dueDate = dueDate
        _draftDate = State(initialValue: initialDate)
        _displayedMonth = State(initialValue: Self.startOfMonth(initialDate))
        _hourText = State(initialValue: String(format: "%02d", Calendar.autoupdatingCurrent.component(.hour, from: initialDate)))
        _minuteText = State(initialValue: String(format: "%02d", Calendar.autoupdatingCurrent.component(.minute, from: initialDate)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            quickDates
            weekStrip

            Rectangle()
                .fill(TodayPalette.line)
                .frame(height: 0.5)

            monthCalendar

            Rectangle()
                .fill(TodayPalette.line)
                .frame(height: 0.5)

            digitalTime
            footer
        }
        .padding(16)
        .frame(width: 340)
        .background(TodayPalette.surface)
        .onChange(of: focusedTimeField) { field in
            if field == nil { commitManualTime() }
        }
    }

    private var header: some View {
        HStack {
            Text("Дата и время")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            if dueDate != nil {
                Button("Убрать") {
                    dueDate = nil
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var quickDates: some View {
        HStack(spacing: 7) {
            quickDateButton("Сегодня", daysFromToday: 0, hour: 18)
            quickDateButton("Завтра", daysFromToday: 1, hour: 9)
            quickDateButton("Через неделю", daysFromToday: 7, hour: 9)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 2) {
            ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                Button {
                    selectDay(date)
                } label: {
                    VStack(spacing: 5) {
                        Text(weekdaySymbols[index])
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 13, weight: isSelected(date) ? .semibold : .regular))
                            .foregroundStyle(isSelected(date) ? Color.white : Color.primary)
                            .frame(width: 28, height: 28)
                            .background(isSelected(date) ? TodayPalette.accent : Color.clear, in: Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 8)
        .background(TodayPalette.raised, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(TodayPalette.border, lineWidth: 0.6)
        }
    }

    private var monthCalendar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button { moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 3
            ) {
                ForEach(monthDates, id: \.self) { date in
                    dayButton(date)
                }
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = isSelected(date)
        let inDisplayedMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectDay(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : inDisplayedMonth ? Color.primary : Color.secondary.opacity(0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? TodayPalette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if isToday && !selected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(TodayPalette.accent.opacity(0.7), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var digitalTime: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Время")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 9) {
                timeButton(systemImage: "minus", delta: -15)

                HStack(spacing: 3) {
                    timeTextField(text: $hourText, field: .hour, range: 0...23)

                    Text(":")
                        .font(.system(size: 27, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)

                    timeTextField(text: $minuteText, field: .minute, range: 0...59)
                }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(TodayPalette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(focusedTimeField == nil ? TodayPalette.border : TodayPalette.accent.opacity(0.85), lineWidth: focusedTimeField == nil ? 0.7 : 1.2)
                    }

                timeButton(systemImage: "plus", delta: 15)
            }

            Text(focusedTimeField == nil ? "Нажмите на время для ручного ввода" : "Введите время и нажмите Enter")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func timeTextField(
        text: Binding<String>,
        field: TimeField,
        range: ClosedRange<Int>
    ) -> some View {
        TextField("00", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 27, weight: .medium, design: .monospaced))
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: 47)
            .focused($focusedTimeField, equals: field)
            .onChange(of: text.wrappedValue) { value in
                let cleaned = String(value.filter(\.isNumber).prefix(2))
                if cleaned != value { text.wrappedValue = cleaned }
                applyManualTimeIfValid()

                if field == .hour, cleaned.count == 2,
                   let number = Int(cleaned), range.contains(number) {
                    focusedTimeField = .minute
                }
            }
            .onSubmit {
                commitManualTime()
                focusedTimeField = nil
            }
    }

    private func timeButton(systemImage: String, delta: Int) -> some View {
        Button {
            draftDate = calendar.date(byAdding: .minute, value: delta, to: draftDate) ?? draftDate
            displayedMonth = Self.startOfMonth(draftDate)
            syncTimeFields()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(TodayPalette.hover, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Text(summaryText)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Готово") {
                dueDate = draftDate
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
            .frame(height: 32)
            .background(TodayPalette.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .keyboardShortcut(.defaultAction)
        }
    }

    private func quickDateButton(_ title: String, daysFromToday: Int, hour: Int) -> some View {
        Button(title) {
            let day = calendar.date(byAdding: .day, value: daysFromToday, to: Date()) ?? Date()
            draftDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
            displayedMonth = Self.startOfMonth(draftDate)
            syncTimeFields()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11.5))
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(TodayPalette.hover, in: Capsule())
    }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekDates: [Date] {
        let weekday = calendar.component(.weekday, from: draftDate)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: draftDate)) ?? draftDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var monthDates: [Date] {
        let monthStart = Self.startOfMonth(displayedMonth)
        let weekday = calendar.component(.weekday, from: monthStart)
        let daysFromMonday = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: monthStart) ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var summaryText: String {
        draftDate.formatted(.dateTime.day().month(.wide).hour().minute())
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: draftDate)
    }

    private func selectDay(_ date: Date) {
        let time = calendar.dateComponents([.hour, .minute], from: draftDate)
        draftDate = calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
        displayedMonth = Self.startOfMonth(date)
    }

    private func moveMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    private func applyManualTimeIfValid() {
        guard let hour = Int(hourText), (0...23).contains(hour),
              let minute = Int(minuteText), (0...59).contains(minute) else { return }
        draftDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: draftDate) ?? draftDate
    }

    private func commitManualTime() {
        let currentHour = calendar.component(.hour, from: draftDate)
        let currentMinute = calendar.component(.minute, from: draftDate)
        let hour = min(max(Int(hourText) ?? currentHour, 0), 23)
        let minute = min(max(Int(minuteText) ?? currentMinute, 0), 59)
        draftDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: draftDate) ?? draftDate
        syncTimeFields()
    }

    private func syncTimeFields() {
        hourText = String(format: "%02d", calendar.component(.hour, from: draftDate))
        minuteText = String(format: "%02d", calendar.component(.minute, from: draftDate))
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func defaultDate() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
