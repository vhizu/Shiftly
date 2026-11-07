import SwiftUI

struct EarningsCalendarView: View {
    @EnvironmentObject private var store: ShiftStore
    @ObservedObject var settings: PayrollSettings
    let month: Date
    @State private var picked: Date? = nil
    @State private var mascotTap = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private var calendar: Calendar { .current }

    var body: some View {
        let ledger = EarningsCalculator.month(store: store, settings: settings, date: month)
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Календарь заработка", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                Text("ПРОГНОЗ")
                    .font(.caption2.bold()).tracking(1.1)
                    .foregroundStyle(.white.opacity(0.60))
            }
            HStack(spacing: 9) {
                amountTile("По записям", ledger.actual, symbol: "checkmark.circle")
                amountTile("По графику", ledger.forecast, symbol: "calendar")
            }
            Button {
                mascotTap += 1
                ShiftlyFeedback.light()
            } label: {
                Label(MascotLines.phrase(for: .earnings, index: mascotTap), systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Text("Премия: \(ledger.bonus.formatted(.currency(code: "RUB"))) · Включена один раз за месяц")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { name in
                    Text(name).font(.caption2).foregroundStyle(.white.opacity(0.54))
                }
                let firstWeekday = (calendar.component(.weekday, from: ledger.days.first?.date ?? month) + 5) % 7
                ForEach(0..<firstWeekday, id: \.self) { _ in Color.clear.frame(height: 60) }
                ForEach(ledger.days) { day in
                    Button {
                        picked = day.date
                        ShiftlyFeedback.light()
                    } label: {
                        VStack(spacing: 5) {
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(day.amount > 0 ? shortAmount(day.amount) : "—")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .minimumScaleFactor(0.7).lineLimit(1)
                                .foregroundStyle(day.amount > 0 ? (day.isOvertime ? Color.orange : Color(red: 0.80, green: 0.68, blue: 0.99)) : .white.opacity(0.35))
                            Circle().fill(day.actual > 0 ? Color.green : day.forecast > 0 ? Color.purple : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity).frame(height: 57)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                            picked.map { calendar.isDate($0, inSameDayAs: day.date) } == true ? Color.purple : .clear,
                            lineWidth: 1.3))
                    }.buttonStyle(.plain)
                }
            }
            if let selected = ledger.days.first(where: { item in
                picked.map { calendar.isDate($0, inSameDayAs: item.date) } == true
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))))
                        .font(.subheadline.bold())
                    Text(selected.description).font(.caption).foregroundStyle(.white.opacity(0.76))
                    HStack {
                        Text("Записи: \(selected.actual.formatted(.currency(code: "RUB")))")
                        Spacer()
                        Text("План: \(selected.forecast.formatted(.currency(code: "RUB")))")
                    }.font(.caption2).foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Точка: зелёная — фактическая запись, фиолетовая — план. Оранжевая сумма — подработка. Суммы ориентировочные, без налогов.")
                .font(.caption).foregroundStyle(.white.opacity(0.66))
        }
        .padding(16)
        .shiftlyGlass(radius: 23)
        .onChange(of: month) { _, _ in picked = nil }
    }

    private func amountTile(_ title: String, _ sum: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(sum, format: .currency(code: "RUB"))
                .font(.subheadline.bold()).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func shortAmount(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.1fк", value / 1000) }
        return String(format: "%.0f", value)
    }
}
