import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var extraDate = Date()
    @State private var night = false
    @State private var message = ""
    @State private var editDay: EditableScheduleDay? = nil
    @AppStorage("shiftly.pay.paidHours") private var paidHoursPerShift = 11.0
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private var cal: Calendar { .current }
    private var extraStart: Date {
        cal.date(bySettingHour: night ? 20 : 8, minute: 0, second: 0, of: extraDate) ?? extraDate
    }
    private var conflict: String? { store.extraConflictReason(extraDate, night: night) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Прошлый месяц")
                        Spacer()
                        Text(ruMonth(month)).font(.headline)
                        Spacer()
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Следующий месяц")
                    }
                    .padding(.vertical, 10)
                    .tint(.purple)

                    Text("Нажми на день, чтобы поставить выходной, отпуск, больничный или изменить смену.")
                        .font(.caption).foregroundStyle(.white.opacity(0.69))
                        .padding(.horizontal, 4)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { title in
                            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.57))
                        }
                        ForEach(0..<leadingBlanks(), id: \.self) { _ in Color.clear.frame(height: 59) }
                        ForEach(monthDays(), id: \.self) { day in
                            let kind = store.dayKind(on: day)
                            let hasExtra = store.data.extras.contains { cal.isDate($0.start, inSameDayAs: day) }
                            let breakMinutes = store.data.sessions.filter { cal.isDate($0.start, inSameDayAs: day) }
                                .reduce(0.0) { $0 + store.breakSeconds($1) / 60 }
                            Button {
                                editDay = EditableScheduleDay(date: day)
                                ShiftlyFeedback.light()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                                    Text(kind.shortLabel).font(.caption.bold()).foregroundStyle(scheduleColor(kind))
                                    HStack(spacing: 3) {
                                        if hasExtra { Circle().fill(.orange).frame(width: 5, height: 5) }
                                        if breakMinutes > 0 { Capsule().fill(.pink).frame(width: 13, height: 3) }
                                    }.frame(height: 5)
                                }
                                .frame(maxWidth: .infinity).frame(height: 55)
                                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(
                                    cal.isDateInToday(day) ? Color.purple :
                                    store.dayOverride(on: day) != nil ? Color.cyan.opacity(0.7) : .clear,
                                    lineWidth: 1.4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.formatted(.dateTime.day().month())), \(kind.title). Изменить день")
                        }
                    }
                    Text("Д — день · Н — ночь · В — выходной · О — отпуск · Б — больничный · оранжевая точка — подработка")
                        .font(.caption).foregroundStyle(.white.opacity(0.67))
                        .padding(.horizontal, 4)

                    NavigationLink { NextShiftView() } label: {
                        ShiftlyMenuRow(symbol: "calendar.badge.clock", title: "Следующая смена",
                                       subtitle: "Время до выхода на работу", accent: .cyan)
                    }.buttonStyle(.plain)

                    ShiftlySectionHeader(title: "Подработки")
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Добавить подработку", systemImage: "calendar.badge.plus")
                            .font(.headline)
                        HStack {
                            Label("Дата", systemImage: "calendar")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.79))
                            Spacer()
                            DatePicker("Дата", selection: $extraDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }
                        Divider().overlay(Color.white.opacity(0.08))
                        Picker("Тип смены", selection: $night) {
                            Text("День · 08–20").tag(false)
                            Text("Ночь · 20–08").tag(true)
                        }
                        .pickerStyle(.segmented)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("ПРЕДПРОСМОТР").font(.caption2.bold()).tracking(1.2)
                                Spacer()
                                Text("12 ч · \(String(format: "%.0f", paidHoursPerShift)) оплач.").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(0.65))
                            Text("\(ruDate(extraStart)) — \(extraStart.addingTimeInterval(12 * 3600).formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "ru_RU"))))")
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                            Label(conflict == nil ? "Пересечений с графиком нет" : "Добавить нельзя",
                                  systemImage: conflict == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(conflict == nil ? Color.green : Color.orange)
                            if let conflict {
                                Text(conflict).font(.caption).foregroundStyle(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                        Button {
                            if store.addExtra(extraDate, night: night) {
                                message = "Подработка добавлена"
                                ShiftlyFeedback.success()
                            } else {
                                message = store.extraConflictReason(extraDate, night: night) ?? "Не удалось добавить"
                                ShiftlyFeedback.medium()
                            }
                        } label: {
                            Label("Добавить подработку", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ShiftlyPrimaryButtonStyle())
                        .disabled(conflict != nil)
                        if !message.isEmpty {
                            Text(message).font(.caption)
                                .foregroundStyle(message == "Подработка добавлена" ? Color.green : Color.orange)
                        }
                        if !store.data.extras.isEmpty {
                            Divider().overlay(Color.white.opacity(0.10))
                            Text("Запланированные подработки")
                                .font(.caption.bold()).foregroundStyle(.white.opacity(0.68))
                            ForEach(store.data.extras.sorted(by: { $0.start > $1.start })) { extra in
                                HStack(spacing: 10) {
                                    Image(systemName: extra.isNight ? "moon.stars.fill" : "sun.max.fill")
                                        .foregroundStyle(.orange)
                                    Text(ruDate(extra.start)).font(.subheadline)
                                    Spacer(minLength: 6)
                                    Button(role: .destructive) {
                                        store.removeExtra(extra.id)
                                    } label: {
                                        Image(systemName: "trash").padding(5)
                                    }.accessibilityLabel("Удалить подработку")
                                }
                            }
                        }
                        Label("Правило 42 часов: условия предприятия ещё не уточнены. Автоматически не блокируем.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.white.opacity(0.63))
                    }
                    .padding(16)
                    .shiftlyGlass(radius: 22)

                    ShiftlySectionHeader(title: "Управление графиком")
                    NavigationLink { ScheduleEditorView() } label: {
                        ShiftlyMenuRow(symbol: "repeat", title: "Настроить мой цикл",
                                       subtitle: "Дни, ночи, выходные · повторять автоматически", accent: .purple)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .shiftlyTabClearance()
            .background(ShiftlyBackdrop())
            .navigationTitle("График")
            .sheet(item: $editDay) { selected in
                ScheduleDayEditor(date: selected.date)
                    .environmentObject(store)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func moveMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: month) { month = next }
    }
    private func monthDays() -> [Date] {
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let count = cal.range(of: .day, in: .month, for: start)?.count else { return [] }
        return (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    private func leadingBlanks() -> Int {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return 0 }
        return (cal.component(.weekday, from: first) + 5) % 7
    }
}
