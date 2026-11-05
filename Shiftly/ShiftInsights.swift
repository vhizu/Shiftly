import Foundation
import SwiftUI

// Presentation helpers deliberately do not modify the saved ShiftData schema.
// Old 1.4/1.5 backups can still be decoded by Shiftly 1.6.
enum RestForecast {
    static func message(remaining: TimeInterval, minutesPerBreak: Int,
                        untilShiftEnd: TimeInterval, active: Bool) -> String {
        if remaining <= 0 { return "Общий лимит исчерпан — новых минут отдыха нет" }
        let oneBreak = Double(max(1, minutesPerBreak) * 60)
        let count = Int(remaining / oneBreak)
        if untilShiftEnd <= 0 { return "Смена закончилась · лимит: \(Int(remaining / 60)) мин" }
        if count <= 0 { return "Осталось \(Int(remaining / 60)) мин — меньше одного полного перекура" }
        let gapMinutes = Int(max(0, untilShiftEnd / Double(count + 1) / 60))
        let suffix = active ? " · текущий перекур уже идёт" : ""
        return "Хватит примерно на \(count) по \(minutesPerBreak) мин · интервал ~\(gapMinutes) мин\(suffix)"
    }
}

struct NeonNightBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.015, blue: 0.105),
                                        Color(red: 0.025, green: 0.012, blue: 0.045),
                                        .black],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.purple.opacity(0.25))
                    .frame(width: geometry.size.width * 0.95, height: geometry.size.width * 0.95)
                    .blur(radius: 90)
                    .offset(x: geometry.size.width * 0.40, y: -geometry.size.height * 0.25)
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .frame(width: geometry.size.width * 0.70, height: geometry.size.width * 0.70)
                    .blur(radius: 95)
                    .offset(x: -geometry.size.width * 0.45, y: geometry.size.height * 0.24)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct BreakHubView: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPastEditor = false
    @State private var minutesAgo = 10
    @State private var message: String?
    @State private var addedBreak = false

    private var selectedSession: WorkSession? {
        store.current ?? store.data.sessions.max(by: { $0.start < $1.start })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("ЦЕНТР ПЕРЕКУРОВ", systemImage: "cup.and.saucer.fill")
                            .font(.caption.bold()).tracking(1.6).foregroundStyle(.purple)
                        Text("Твоё время отдыха").font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Добавь забытый перекур или продолжи уже начатый — без потери минут.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(19).shiftlyGlass(radius: 25, emphasis: true)
                    if let session = selectedSession {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Смена: \(ruDate(session.start))").font(.headline)
                            let used = store.breakSeconds(session)
                            HStack {
                                Label("Всего отдыхал", systemImage: "clock")
                                Spacer()
                                Text(timeString(used)).monospacedDigit().bold()
                            }
                            HStack {
                                Label("Осталось", systemImage: "hourglass")
                                Spacer()
                                Text(timeString(max(0, Double(session.breakLimitMinutes * 60) - used)))
                                    .monospacedDigit().bold()
                            }
                            ProgressView(value: min(1, max(0,
                                used / Double(max(1, session.breakLimitMinutes * 60)))))
                                .tint(.purple)
                        }
                        .padding(16)
                        .shiftlyGlass(radius: 22)

                        Button { showPastEditor = true } label: {
                            Label("+ Добавить забытый перекур", systemImage: "clock.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ShiftlyPrimaryButtonStyle())
                        .controlSize(.large)

                        if store.current?.id == session.id && !store.isOnBreak {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Уже курю, но таймер не запустил").font(.headline)
                                Text("Отсчёт пойдёт от выбранного времени в прошлом.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Picker("Началось", selection: $minutesAgo) {
                                    ForEach([5, 10, 15, 20, 30], id: \.self) { min in
                                        Text("\(min) мин назад").tag(min)
                                    }
                                }
                                .pickerStyle(.menu)
                                Button("Запустить с учётом пропущенного времени") {
                                    message = store.startMissedBreak(sessionID: session.id, minutesAgo: minutesAgo)
                                    addedBreak = message == nil
                                    if addedBreak { message = "Перекур запущен с правильным временем начала" }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .shiftlyGlass(radius: 22)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Последние перекуры").font(.headline)
                            if session.breaks.isEmpty {
                                Text("Записей пока нет").foregroundStyle(.secondary)
                            }
                            ForEach(Array(session.breaks.sorted(by: { $0.start > $1.start }).prefix(5))) { entry in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(ruDate(entry.start)).font(.subheadline)
                                        Text(entry.end == nil ? "Идёт сейчас" : "Завершён")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(timeString(entry.seconds(asOf: Date())))
                                        .font(.subheadline.monospacedDigit())
                                }
                                Divider()
                            }
                        }
                        .padding(16)
                        .shiftlyGlass(radius: 22)
                    } else {
                        ContentUnavailableView("Нет смен", systemImage: "calendar.badge.exclamationmark",
                                               description: Text("Сначала открой приложение во время смены"))
                    }
                    if let message {
                        Text(message).foregroundStyle(addedBreak ? Color.green : Color.orange).font(.callout)
                    }
                    NavigationLink { HistoryView() } label: {
                        Label("Другие смены и исправление записей", systemImage: "clock.arrow.circlepath")
                    }
                }
                .padding()
            }
            .navigationTitle("Перекуры")
            .navigationBarTitleDisplayMode(.inline)
            .background(ShiftlyBackdrop())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
            .sheet(isPresented: $showPastEditor) {
                if let session = selectedSession { QuickPastBreakEditor(sessionID: session.id) }
            }
        }
    }
}

struct QuickPastBreakEditor: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var start = Date().addingTimeInterval(-15 * 60)
    @State private var end = Date()
    @State private var errorMessage: String?
    @State private var initialized = false

    private var shift: WorkSession? { store.data.sessions.first(where: { $0.id == sessionID }) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Когда был перекур?") {
                    DatePicker("Начало", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Конец", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    Text("Данные добавятся в историю и общий лимит. Новый таймер не запустится.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Быстро: длина перекура") {
                    HStack {
                        ForEach([5, 10, 15], id: \.self) { minutes in
                            Button("\(minutes) мин") {
                                let proposed = end.addingTimeInterval(-Double(minutes * 60))
                                start = max(shift?.start ?? proposed, proposed)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Добавить в историю") {
                        errorMessage = store.addPastBreak(sessionID: sessionID, start: start, end: end)
                        if errorMessage == nil { dismiss() }
                    }
                    .disabled(end <= start || end > Date())
                }
            }
            .navigationTitle("Забытый перекур")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(ShiftlyBackdrop())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .onAppear {
                guard !initialized else { return }
                initialized = true
                let suggestedEnd = min(Date(), shift?.end ?? Date())
                end = suggestedEnd
                start = max(shift?.start ?? suggestedEnd,
                            suggestedEnd.addingTimeInterval(-15 * 60))
            }
        }
    }
}

struct NextShiftView: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                ScrollView {
                    VStack(spacing: 19) {
                        VStack(spacing: 14) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(palette.accent)
                                .symbolEffect(.pulse, options: .repeating)
                                .padding(.top, 11)
                            Text("СЛЕДУЮЩАЯ СМЕНА")
                                .font(.caption.bold()).tracking(2).foregroundStyle(palette.accent)
                            if let next = store.nextScheduledShift(after: tick.date) {
                                let night = Calendar.current.component(.hour, from: next.interval.start) == 20
                                Text(night ? "Ночная 🌙" : "Дневная ☀️")
                                    .font(.system(size: 29, weight: .bold, design: .rounded))
                                Text(next.extra ? "Внеплановая подработка" : "По основному графику")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(timeString(max(0, next.interval.start.timeIntervalSince(tick.date))))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                                    .foregroundStyle(.white)
                                Text("ДО НАЧАЛА")
                                    .font(.caption2.bold()).tracking(2).foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    ShiftlyStatChip(symbol: "calendar", title: "Начало", value: next.interval.start.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "ru_RU"))))
                                    ShiftlyStatChip(symbol: "flag.checkered", title: "Конец", value: next.interval.end.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "ru_RU"))))
                                }
                                Text("12 часов · 2 дня → выходной → 2 ночи → 3 выходных")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Нет смен на ближайший месяц").foregroundStyle(.secondary)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .shiftlyGlass(radius: 28, emphasis: true)
                    }
                    .padding(17)
                }
                .scrollIndicators(.hidden)
            }
            .background(ShiftlyBackdrop())
            .navigationTitle("Следующая смена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
    }
}

struct ShiftReportView: View {
    @EnvironmentObject var store: ShiftStore
    let sessionID: UUID
    var body: some View {
        ScrollView {
            if let session = store.data.sessions.first(where: { $0.id == sessionID }) {
                let now = Date()
                let elapsed = store.breakSeconds(session, now: now)
                let worked = store.workSeconds(session, now: now)
                let longest = session.breaks.map { $0.seconds(asOf: now) }.max() ?? 0
                let remaining = Double(session.breakLimitMinutes * 60) - elapsed
                let isNight = Calendar.current.component(.hour, from: session.start) >= 14
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("ОТЧЁТ ОПЕРАТОРА", systemImage: "chart.bar.doc.horizontal")
                            .font(.caption.bold()).tracking(1.8).foregroundStyle(.purple)
                        Text("Смена завершена 💜").font(.system(size: 29, weight: .bold, design: .rounded))
                        Text(ruDate(session.start)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).shiftlyGlass(radius: 24, emphasis: true)
                    reportRow("Тип", isNight ? "Ночная" : "Дневная", "moon.stars.fill")
                    reportRow("Работа", timeString(worked), "briefcase.fill")
                    reportRow("Отдых", timeString(elapsed), "cup.and.saucer.fill")
                    reportRow("Перекуры", "\(session.breaks.count)", "number")
                    reportRow("Самый длинный", timeString(longest), "timer")
                    reportRow("Остаток лимита", remaining < 0 ? "Превышение \(timeString(-remaining))" : timeString(remaining), "hourglass")
                    if let end = session.end {
                        Text("Завершена: \(ruDate(end))").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Промежуточные итоги — смена ещё идёт")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ShareLink(item: shareText(session: session, worked: worked,
                                             rested: elapsed, longest: longest, remaining: remaining)) {
                        Label("Поделиться отчётом", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ShiftlyPrimaryButtonStyle())
                }
                .padding()
            } else {
                ContentUnavailableView("Смена не найдена", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .navigationTitle("Отчёт смены")
        .navigationBarTitleDisplayMode(.inline)
        .background(ShiftlyBackdrop())
    }

    private func reportRow(_ name: String, _ value: String, _ symbol: String) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(.purple).frame(width: 27)
            Text(name)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
        .padding(13)
        .shiftlyGlass(radius: 17)
    }

    private func shareText(session: WorkSession, worked: Double,
                           rested: Double, longest: Double, remaining: Double) -> String {
        "Shiftly · Отчёт за \(ruDate(session.start))\n" +
        "Работа: \(timeString(worked))\n" +
        "Перекуров: \(session.breaks.count)\n" +
        "Отдых: \(timeString(rested))\n" +
        "Самый длинный: \(timeString(longest))\n" +
        "Остаток лимита: \(timeString(max(0, remaining)))"
    }
}

struct PayrollProjection {
    let future: Double
    let total: Double
    let upcomingShifts: Int

    @MainActor
    static func calculate(store: ShiftStore, settings: PayrollSettings, month: Date) -> PayrollProjection {
        let actual = payroll(for: store, settings: settings, month: month).estimated
        let now = Date()
        let cal = Calendar.current
        guard let monthRange = cal.dateInterval(of: .month, for: month),
              monthRange.end > now else {
            return PayrollProjection(future: 0, total: actual, upcomingShifts: 0)
        }
        var future = 0.0
        var count = 0
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 31
        let first = monthRange.start
        var planned: [(interval: DateInterval, extra: Bool)] = []
        for offset in 0..<days {
            guard let date = cal.date(byAdding: .day, value: offset, to: first),
                  let interval = store.regularInterval(on: date) else { continue }
            planned.append((interval, false))
        }
        for extra in store.data.extras {
            planned.append((DateInterval(start: extra.start, end: extra.end), true))
        }
        for item in planned {
            guard let inMonth = item.interval.intersection(with: monthRange),
                  inMonth.end > now else { continue }
            // A completed session is already represented by actual payroll.
            if let existing = store.data.sessions.first(where: {
                abs($0.start.timeIntervalSince(item.interval.start)) < 60
            }), existing.end != nil { continue }
            let start = max(inMonth.start, now)
            guard inMonth.end > start else { continue }
            let remaining = DateInterval(start: start, end: inMonth.end)
            let hours = remaining.duration / 3600
            let night = nightHours(in: remaining)
            let base = max(0, settings.hourlyRate)
            let multiplier = item.extra ? max(0, settings.overtimeMultiplier) : 1.0
            future += base * (hours * multiplier + night * max(0, settings.nightMultiplier - 1))
            count += 1
        }
        return PayrollProjection(future: future, total: actual + future,
                                 upcomingShifts: count)
    }
}
