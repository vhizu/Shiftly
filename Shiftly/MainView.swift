import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let violet = Color(red: 0.70, green: 0.43, blue: 0.98)

struct MainView: View {
    @EnvironmentObject var store: ShiftStore
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Главная", systemImage: "house.fill") }
            StatsView().tabItem { Label("Статистика", systemImage: "chart.bar.fill") }
            CalendarView().tabItem { Label("График", systemImage: "calendar") }
            PayrollView().tabItem { Label("Зарплата", systemImage: "rublesign.circle") }
            MoreView().tabItem { Label("Ещё", systemImage: "ellipsis.circle") }
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { HistoryView() } label: { Label("История смен и перекуров", systemImage: "clock.arrow.circlepath") }
                NavigationLink { LineJournalView() } label: { Label("Журнал оператора", systemImage: "wrench.and.screwdriver") }
                NavigationLink { NextShiftView() } label: { Label("Следующая смена", systemImage: "calendar.badge.clock") }
                NavigationLink { BreakHubView() } label: { Label("Центр перекуров", systemImage: "cup.and.saucer.fill") }
                NavigationLink { SettingsView() } label: { Label("Настройки", systemImage: "gearshape") }
            }
            .navigationTitle("Ещё")
        }
    }
}

func ruDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMM yyyy 'в' HH:mm"
    return formatter.string(from: date)
}

func timeString(_ seconds: TimeInterval) -> String {
    let n = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", n / 3600, (n / 60) % 60, n % 60)
}

struct MascotPanel: View {
    let mode: Int // 0 off, 1 work, 2 break
    let remainingSingle: TimeInterval
    var compact: Bool = false
    @State private var tapped = false
    private var asset: String {
        if mode == 0 { return "MascotDone" }
        if mode == 2 && remainingSingle > 120 { return "MascotBreak" }
        return "MascotWork"
    }
    private var stage: String {
        guard mode == 2 else { return mode == 1 ? "Рабочий настрой" : "Сладких снов" }
        if remainingSingle <= 0 { return "Время вышло!" }
        if remainingSingle <= 60 { return "Осталась минута" }
        if remainingSingle <= 120 { return "Пора возвращаться" }
        if remainingSingle <= 300 { return "Скоро обратно" }
        return "Кофейная пауза"
    }
    private var caption: String {
        if tapped { return mode == 2 ? "Я слежу за твоими 15 минутами 💜" : mode == 1 ? "Держим темп, оператор!" : "Ты заслужил отдых 💜" }
        if mode == 2 && remainingSingle <= 0 { return "Эй, пора заканчивать перекур! ⏰" }
        if mode == 2 && remainingSingle <= 60 { return "Осталась минута! ☕" }
        if mode == 2 && remainingSingle <= 120 { return "Эй, допивай кофе — две минуты! 💜" }
        if mode == 2 && remainingSingle <= 300 { return "Допивай кофе, скоро работать 💜" }
        return mode == 2 ? "Наконец-то перерыв ☕" : mode == 1 ? "Смена в деле!" : "До следующей смены отдыхаем"
    }
    var body: some View {
        let height: CGFloat = compact ? 96 : 232
        ZStack(alignment: .bottomLeading) {
            Image(asset).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: height)
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: mode == 2 && remainingSingle <= 60 ? "exclamationmark.circle.fill" : "heart.fill")
                        .symbolEffect(.pulse, options: .repeating)
                    Text(stage.uppercased())
                }
                .font(.caption2.bold()).foregroundStyle(remainingSingle <= 60 && mode == 2 ? .orange : violet)
                Text(caption).font(compact ? .caption : .headline).lineLimit(compact ? 2 : 3)
            }.padding(compact ? 9 : 14)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(violet.opacity(0.6), lineWidth: 1))
        .onTapGesture { tapped.toggle(); UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        .accessibilityLabel("Операторша. " + caption)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: ShiftStore
    @AppStorage("shiftly.compactHome") private var compact = false
    @AppStorage("shiftly.neonNight") private var neonNight = true
    @State private var showBreakHub = false
    @State private var showNextShift = false
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                ScrollView {
                    VStack(spacing: compact ? 10 : 14) {
                        HStack {
                            Text("Рабочая панель").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { compact.toggle() } label: {
                                Label(compact ? "Крупно" : "Компактно", systemImage: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 10) {
                            Button { showBreakHub = true } label: {
                                Label("Забытый перекур", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            Button { showNextShift = true } label: {
                                Image(systemName: "calendar.badge.clock")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Следующая смена")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        let active = store.current?.breaks.last(where: { $0.end == nil })
                        let singleRemaining = active.map { Double(store.perBreakLimitMinutes * 60) - now.timeIntervalSince($0.start) } ?? Double(store.perBreakLimitMinutes * 60)
                        MascotPanel(mode: store.current == nil ? 0 : store.isOnBreak ? 2 : 1,
                                    remainingSingle: singleRemaining, compact: compact)
                        if let s = store.current {
                            let spent = store.breakSeconds(s, now: now)
                            let totalRemaining = Double(s.breakLimitMinutes * 60) - spent
                            let scheduledEnd = s.end ?? s.start.addingTimeInterval(12 * 3600)
                            let timeToEnd = max(0, scheduledEnd.timeIntervalSince(now))
                            VStack(spacing: compact ? 8 : 12) {
                                Label(store.isOnBreak ? "Перерыв" : "Смена идёт", systemImage: store.isOnBreak ? "cup.and.saucer.fill" : "briefcase.fill")
                                    .font(.headline).foregroundStyle(violet)
                                Text("Начало: " + ruDate(s.start))
                                    .font(.caption).foregroundStyle(.secondary)
                                if store.isOnBreak {
                                    ShiftRing(remaining: singleRemaining,
                                              total: Double(store.perBreakLimitMinutes * 60),
                                              subtitle: "ТЕКУЩИЙ ПЕРЕКУР", compact: compact)
                                } else if !compact {
                                    ShiftRing(remaining: timeToEnd, total: 12 * 3600,
                                              subtitle: "ДО КОНЦА СМЕНЫ")
                                }
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text("Общий лимит отдыха").font(.caption.bold())
                                        Spacer()
                                        Text("\(Int(max(0, totalRemaining) / 60)) / \(s.breakLimitMinutes) мин")
                                            .font(.caption.bold().monospacedDigit())
                                    }
                                    ProgressView(value: min(1, max(0, totalRemaining / Double(max(1, s.breakLimitMinutes * 60)))))
                                        .tint(totalRemaining < 300 ? .orange : violet)
                                    Text("До конца смены: \(timeString(timeToEnd)) · отдых: \(timeString(max(0, totalRemaining)))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(RestForecast.message(remaining: totalRemaining,
                                        minutesPerBreak: store.perBreakLimitMinutes,
                                        untilShiftEnd: timeToEnd, active: store.isOnBreak))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if store.isOnBreak && singleRemaining < 0 {
                                        Text("Перекур превышен на \(timeString(-singleRemaining))")
                                            .font(.caption.bold()).foregroundStyle(.orange)
                                    }
                                    if totalRemaining < 0 {
                                        Text("Общий лимит превышен на \(timeString(-totalRemaining))")
                                            .font(.caption.bold()).foregroundStyle(.red)
                                    }
                                }
                                HStack {
                                    metric("Работа", timeString(store.workSeconds(s, now: now)))
                                    metric("Перекуры", timeString(spent))
                                }
                            }.padding(compact ? 12 : 16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            Button(store.isOnBreak ? "Вернулся к работе" : "Начать перекур") {
                                store.toggleBreak()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                            HStack(spacing: 10) {
                                Button { showBreakHub = true } label: {
                                    Label("Центр перекуров", systemImage: "cup.and.saucer.fill")
                                }
                                .buttonStyle(.bordered)
                                Button { showNextShift = true } label: {
                                    Label("Следующая", systemImage: "calendar.badge.clock")
                                }
                                .buttonStyle(.bordered)
                            }
                            Button("Забытый перекур +", systemImage: "clock.badge.plus") {
                                showBreakHub = true
                            }
                            .buttonStyle(.bordered)
                            Button("Завершить смену", role: .destructive) { store.endWork() }
                        } else {
                            Text("Сейчас выходной").font(.title2.bold())
                            Text("Смены автоматически запускаются по графику. Внеплановую можно начать вручную.")
                                .foregroundStyle(.secondary)
                            Button("Посмотреть следующую смену") { showNextShift = true }
                                .buttonStyle(.bordered)
                            if let completed = store.data.sessions.last(where: { $0.end != nil && Date().timeIntervalSince($0.end!) < 48 * 3600 }) {
                                NavigationLink { ShiftReportView(sessionID: completed.id) } label: {
                                    Label("Итоги прошлой смены", systemImage: "chart.bar.doc.horizontal")
                                }
                            }
                            Button("Начать смену") { store.startWork() }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }.padding()
                }
                .background {
                    if neonNight && (store.current.map { Calendar.current.component(.hour, from: $0.start) >= 14 } ?? false) {
                        NeonNightBackground()
                    }
                }
            }
            .navigationTitle("Shiftly")
            .sheet(isPresented: $showBreakHub) { BreakHubView() }
            .sheet(isPresented: $showNextShift) { NextShiftView() }
        }
    }
    func metric(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline.monospacedDigit()) }
            .frame(maxWidth: .infinity)
    }
}

struct StatsView: View {
    @EnvironmentObject var store: ShiftStore
    @State private var month = Date()
    var body: some View {
        NavigationStack {
            ScrollView {
                let sessions = store.data.sessions.filter { Calendar.current.isDate($0.start, equalTo: month, toGranularity: .month) }
                let completed = sessions.filter { $0.end != nil }
                let hours = sessions.reduce(0.0) { $0 + store.workSeconds($1) } / 3600
                let breakSeconds = sessions.reduce(0.0) { $0 + store.breakSeconds($1) }
                let allBreaks = sessions.flatMap(\.breaks)
                let average = allBreaks.isEmpty ? 0 : Int(breakSeconds / Double(allBreaks.count) / 60)
                let within = completed.filter { store.breakSeconds($0) <= Double($0.breakLimitMinutes * 60) }.count
                let day = sessions.filter { Calendar.current.component(.hour, from: $0.start) < 14 }
                let night = sessions.filter { Calendar.current.component(.hour, from: $0.start) >= 14 }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.headline); Spacer()
                        Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                    }
                    stat("Отработано", String(format: "%.1f ч", hours), "clock.fill")
                    stat("Перерывы", String(format: "%.1f ч", breakSeconds / 3600), "cup.and.saucer.fill")
                    stat("Средний перекур", "\(average) мин", "timer")
                    stat("Количество перекуров", "\(allBreaks.count)", "number")
                    stat("Смены", "\(completed.count) завершено", "calendar.badge.checkmark")
                    Text("Дневные и ночные смены").font(.title3.bold())
                    comparison("Дневные", sessions: day, color: .green)
                    comparison("Ночные", sessions: night, color: .purple)
                    Text("Дисциплина лимитов").font(.title3.bold())
                    ProgressView(value: Double(within), total: Double(max(1, completed.count))).tint(violet)
                    Text("В пределах лимита: \(within) из \(completed.count) завершённых смен")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Достижения").font(.title2.bold())
                    achievement("Первая смена", unlocked: completed.count >= 1, progress: completed.count, goal: 1)
                    achievement("Режим завода", unlocked: completed.count >= 10, progress: completed.count, goal: 10)
                    achievement("Дисциплина", unlocked: within >= 5, progress: within, goal: 5)
                    Text("Статистика текущей смены пересчитывается по фактически прошедшему времени.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Статистика")
        }
    }
    func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack { Image(systemName: symbol).foregroundStyle(violet).frame(width: 32); Text(title); Spacer(); Text(value).bold() }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    func comparison(_ title: String, sessions: [WorkSession], color: Color) -> some View {
        let seconds = sessions.reduce(0.0) { $0 + store.breakSeconds($1) }
        let allowance = sessions.reduce(0.0) { $0 + Double($1.breakLimitMinutes * 60) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title); Spacer(); Text("\(sessions.count) смен · \(Int(seconds / 60)) мин") }
                .font(.subheadline)
            ProgressView(value: min(1, seconds / max(1, allowance))).tint(color)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    func achievement(_ name: String, unlocked: Bool, progress: Int, goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: unlocked ? "trophy.fill" : "lock.fill").foregroundStyle(unlocked ? .yellow : .secondary); Text(name); Spacer(); Text("\(min(progress,goal))/\(goal)").foregroundStyle(.secondary) }
            ProgressView(value: Double(min(progress,goal)), total: Double(goal)).tint(violet)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PayrollView: View {
    @EnvironmentObject var store: ShiftStore
    @StateObject private var pay = PayrollSettings()
    @State private var month = Date()
    var body: some View {
        NavigationStack {
            Form {
                let result = payroll(for: store, settings: pay, month: month)
                Section("Расчёт за месяц") {
                    DatePicker("Месяц", selection: $month, displayedComponents: .date)
                    Text(result.estimated, format: .currency(code: "RUB")).font(.title.bold()).foregroundStyle(violet)
                    LabeledContent("Учтено рабочих часов", value: String(format: "%.1f", result.normalHours))
                    LabeledContent("Из них ночных (22–06)", value: String(format: "%.1f", result.nightHours))
                    LabeledContent("Доп. смены без записи", value: String(format: "%.1f", result.overtimeHours))
                }
                Section("Прогноз до конца месяца") {
                    let forecast = PayrollProjection.calculate(store: store, settings: pay, month: month)
                    Text(forecast.total, format: .currency(code: "RUB"))
                        .font(.title2.bold()).foregroundStyle(violet)
                    LabeledContent("По текущим данным", value: result.estimated.formatted(.currency(code: "RUB")))
                    LabeledContent("По оставшимся сменам", value: forecast.future.formatted(.currency(code: "RUB")))
                    LabeledContent("Осталось смен по графику", value: "\(forecast.upcomingShifts)")
                    Text("Оценка по заданным ставкам. Будущие смены считаются по 12 часов без вычета будущих перерывов; налоги, условия премий и доплаты предприятия не учитываются.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Твои ставки") {
                    HStack { Text("₽ за час"); Spacer(); TextField("0", value: $pay.hourlyRate, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
                    HStack { Text("Коэффициент ночных"); Spacer(); TextField("1.2", value: $pay.nightMultiplier, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70) }
                    HStack { Text("Коэффициент подработки"); Spacer(); TextField("1.5", value: $pay.overtimeMultiplier, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70) }
                    HStack { Text("Премия, ₽"); Spacer(); TextField("0", value: $pay.monthlyBonus, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
                }
                Section { Text("Предварительная оценка, не расчётный лист. Реальные выплаты зависят от правил предприятия, удержаний и того, какие смены уже учтены в истории.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Зарплата")
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var store: ShiftStore
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var extraDate = Date()
    @State private var night = false
    @State private var message = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                        Spacer()
                        Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                    }
                    let days = monthDays()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                        ForEach(0..<leadingBlanks(), id: \.self) { _ in Color.clear.frame(height: 55) }
                        ForEach(days, id: \.self) { day in
                            let label = store.dayLabel(day)
                            let hasExtra = store.data.extras.contains { Calendar.current.isDate($0.start, inSameDayAs: day) }
                            VStack(spacing: 4) {
                                Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                                Text(label).font(.caption.bold()).foregroundStyle(label == "Н" ? .purple : label == "Д" ? .green : .secondary)
                                if hasExtra { Circle().fill(.orange).frame(width: 6, height: 6) }
                            }.frame(maxWidth: .infinity).frame(height: 55).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    Text("Д — день 08–20  ·  Н — ночь 20–08  ·  В — выходной").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Добавить подработку").font(.headline)
                    DatePicker("Дата", selection: $extraDate, displayedComponents: .date)
                    Toggle("Ночная (20:00–08:00)", isOn: $night)
                    Button("Добавить 12-часовую смену") {
                        message = store.addExtra(extraDate, night: night) ? "Подработка добавлена" : "Пересечение с другой сменой — добавление отменено"
                    }.buttonStyle(.borderedProminent)
                    if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
                    ForEach(store.data.extras) { extra in
                        HStack {
                            Circle().fill(.orange).frame(width: 9, height: 9)
                            Text(extra.start.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "ru_RU"))))
                            Spacer()
                            Button(role: .destructive) { store.removeExtra(extra.id) } label: { Image(systemName: "trash") }
                        }.font(.subheadline)
                    }
                    Text("Важно: проверка 42 часов отдыха появится после уточнения правил предприятия.").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("График")
        }
    }
    func monthDays() -> [Date] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let count = cal.range(of: .day, in: .month, for: start)!.count
        return (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    func leadingBlanks() -> Int {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        return (cal.component(.weekday, from: first) + 5) % 7
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: ShiftStore
    var body: some View {
        NavigationStack {
            List(store.data.sessions.reversed()) { session in
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.start.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "ru_RU")))).font(.headline)
                    Text(session.end == nil ? "Смена продолжается" : "Завершена").foregroundStyle(.secondary)
                    Text("Работа: \(timeString(store.workSeconds(session))) · Перекуры: \(timeString(store.breakSeconds(session)))")
                        .font(.caption).monospacedDigit()
                    Text("Лимит: \(session.breakLimitMinutes) мин · Перекуров: \(session.breaks.count)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        NavigationLink("Исправить") { SessionEditor(sessionID: session.id) }.font(.caption)
                        Spacer()
                        NavigationLink("Отчёт смены") { ShiftReportView(sessionID: session.id) }.font(.caption)
                    }
                }.padding(.vertical, 4)
            }.navigationTitle("История").overlay { if store.data.sessions.isEmpty { ContentUnavailableView("История пуста", systemImage: "clock") } }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: ShiftStore
    @ObservedObject private var live = LiveDiagnostics.shared
    var body: some View {
        NavigationStack {
            Form {
                Section("Лимит на новую смену") {
                    Picker("Минуты", selection: Binding(get: { store.data.limitMinutes }, set: { store.setLimit($0) })) {
                        ForEach([60, 90, 120, 150, 180, 210, 240], id: \.self) { Text("\($0) мин").tag($0) }
                    }
                    Text("Текущая смена сохраняет лимит, установленный при её запуске.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Один перекур") {
                    Picker("Минут на перекур", selection: Binding(get: { store.perBreakLimitMinutes }, set: { store.setPerBreakLimit($0) })) {
                        ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) мин").tag($0) }
                    }
                    Text("По умолчанию 15 минут. Отдельно от общего лимита смены.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("График") {
                    Toggle("Автоматический учёт", isOn: Binding(get: { store.autoEnabled }, set: { store.setAuto($0) }))
                    Toggle("Напоминания за 1 час и 15 минут", isOn: Binding(get: { store.data.remindEnabled ?? true }, set: { store.setReminders($0) }))
                    Button("Разрешить уведомления") { BreakAlerts.requestPermission() }
                    Text("2 дня → выходной → 2 ночи → 3 выходных")
                    Text("Опорная дата: 4 ноября 2026 — первая ночь").font(.caption).foregroundStyle(.secondary)
                }
                Section("Оформление") {
                    Toggle("Фиолетовый неон на ночной смене",
                        isOn: Binding(get: { UserDefaults.standard.object(forKey: "shiftly.neonNight") as? Bool ?? true },
                                      set: { UserDefaults.standard.set($0, forKey: "shiftly.neonNight") }))
                    Text("Режим включается на ночных сменах. Удобную компактную панель можно выбрать на главной.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Dynamic Island · диагностика") {
                    Text("Разрешены системой: \(live.enabled ? "да" : "нет")")
                    Text(live.status).font(.caption).textSelection(.enabled)
                    Text("Запусти смену и перекур, затем проверь этот статус.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Экспорт и восстановление") { BackupControls() }
                Section("О приложении") {
                    Text("Shiftly \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · сборка \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")")
                    Text("Версия IPA: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    Text("Данные хранятся локально на устройстве.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Настройки")
        }
    }
}

struct ShiftRing: View {
    let remaining: Double
    let total: Double
    let subtitle: String
    var compact: Bool = false
    var body: some View {
        ZStack {
            Circle().stroke(Color.purple.opacity(0.13), lineWidth: 15)
            Circle().trim(from: 0, to: CGFloat(min(1, max(0, remaining / max(1,total)))))
                .stroke(AngularGradient(colors: [.purple, .pink, .purple], center: .center), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.5), value: Int(remaining))
            VStack(spacing: 9) {
                Text(subtitle).font(.caption2.bold()).foregroundStyle(.secondary)
                Text(remaining < 0 ? "+" + timeString(-remaining) : timeString(remaining))
                    .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    .foregroundStyle(remaining < 0 ? .orange : .primary)
                Text("SHIFTLY · OPERATOR").font(.caption2.bold()).tracking(1.2).foregroundStyle(.purple)
            }.padding(20)
        }.frame(width: compact ? 158 : 244, height: compact ? 158 : 244).padding(.vertical, compact ? 0 : 10)
    }
}

struct LineJournalView: View {
    @EnvironmentObject var store: ShiftStore
    @State private var stream = "910"
    @State private var category = "Заметка"
    @State private var details = ""
    @State private var duration = 0
    @State private var editing: LineNote?
    var body: some View {
        NavigationStack {
            Form {
                Section("Новая запись") {
                    Picker("Ручей", selection: $stream) { ForEach(["910","911","912","Другой"], id: \.self) { Text($0) } }
                    Picker("Событие", selection: $category) { ForEach(["Заметка","Остановка","Ремонт","Переналадка","Замена рулона","Запуск"], id: \.self) { Text($0) } }
                    TextField("Что произошло?", text: $details, axis: .vertical).lineLimit(2...5)
                    Stepper("Простой: \(duration) мин", value: $duration, in: 0...720, step: 1)
                    Button("Добавить запись") {
                        store.addNote(LineNote(date: Date(), stream: stream, category: category, details: details, durationMinutes: duration))
                        details = ""; duration = 0
                    }.disabled(details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Записи") {
                    ForEach(store.notes.sorted { $0.date > $1.date }) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(note.category) · \(note.stream)").bold()
                            Text(note.details)
                            Text("\(note.date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "ru_RU")))) · \(note.durationMinutes) мин")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Изменить") { editing = note }.font(.caption)
                                Button("Удалить", role: .destructive) { store.removeNote(note.id) }.font(.caption)
                            }
                        }
                    }
                }
            }.navigationTitle("Журнал линии")
            .sheet(item: $editing) { note in NoteEditor(note: note) }
        }
    }
}

struct NoteEditor: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State var note: LineNote
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Время", selection: $note.date)
                TextField("Ручей", text: $note.stream)
                TextField("Событие", text: $note.category)
                TextField("Описание", text: $note.details, axis: .vertical)
                Stepper("Простой: \(note.durationMinutes) мин", value: $note.durationMinutes, in: 0...720)
            }
            .navigationTitle("Редактирование")
            .toolbar { Button("Сохранить") { store.updateNote(note); dismiss() } }
        }
    }
}

struct SessionEditor: View {
    @EnvironmentObject var store: ShiftStore
    let sessionID: UUID
    @State private var start = Date()
    @State private var end = Date()
    @State private var hasEnd = true
    @State private var ready = false
    @State private var addingPastBreak = false
    var body: some View {
        Form {
            if let session = store.data.sessions.first(where: { $0.id == sessionID }) {
                Section("Смена") {
                    DatePicker("Начало", selection: $start)
                    Toggle("Завершена", isOn: $hasEnd)
                    if hasEnd { DatePicker("Конец", selection: $end) }
                    Button("Сохранить смену") {
                        store.editSession(sessionID, start: start, end: hasEnd ? end : nil)
                    }.disabled(hasEnd && end <= start)
                }
                Section("Перекуры") {
                    Button { addingPastBreak = true } label: {
                        Label("Добавить забытый перекур", systemImage: "plus.circle.fill")
                    }
                    ForEach(session.breaks) { item in
                        NavigationLink {
                            BreakEditor(sessionID: sessionID, item: item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.start.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "ru_RU"))))
                                Text(item.end?.formatted(date: .omitted, time: .shortened) ?? "Идёт")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Корректировка")
        .sheet(isPresented: $addingPastBreak) { PastBreakEditor(sessionID: sessionID) }
        .onAppear {
            guard !ready, let session = store.data.sessions.first(where: { $0.id == sessionID }) else { return }
            start = session.start; end = session.end ?? Date(); hasEnd = session.end != nil; ready = true
        }
    }
}

struct PastBreakEditor: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var start = Date().addingTimeInterval(-15 * 60)
    @State private var end = Date()
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Забытый перекур") {
                    DatePicker("Начало", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Конец", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    Text("Перекур добавится в историю смены и будет учтён в лимите. Таймер и уведомление не запускаются.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Добавить перекур") {
                        if let error = store.addPastBreak(sessionID: sessionID, start: start, end: end) {
                            errorMessage = error
                        } else { dismiss() }
                    }
                    .disabled(end <= start || end > Date())
                }
            }
            .navigationTitle("Добавить перекур")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

struct BreakEditor: View {
    @EnvironmentObject var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    let item: BreakSession
    @State private var start = Date()
    @State private var end = Date()
    @State private var ready = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    var body: some View {
        Form {
            DatePicker("Начало", selection: $start)
            DatePicker("Конец", selection: $end)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
            Button("Сохранить") {
                if let error = store.editBreak(sessionID: sessionID, breakID: item.id, start: start, end: end) {
                    errorMessage = error
                } else { dismiss() }
            }.disabled(end <= start || end > Date())
            Button("Удалить перекур", role: .destructive) { confirmDelete = true }
                .confirmationDialog("Удалить эту запись?", isPresented: $confirmDelete) {
                    Button("Удалить", role: .destructive) {
                        store.removeBreak(sessionID: sessionID, breakID: item.id)
                        dismiss()
                    }
                }
        }
        .navigationTitle("Исправить перекур")
        .onAppear { if !ready { start = item.start; end = item.end ?? Date(); ready = true } }
    }
}

struct BackupControls: View {
    @EnvironmentObject var store: ShiftStore
    @State private var exportingJSON = false
    @State private var exportingCSV = false
    @State private var importing = false
    @State private var message = ""
    var body: some View {
        Button("Сохранить резервную копию JSON") { exportingJSON = true }
        Button("Экспорт CSV") { exportingCSV = true }
        Button("Восстановить из JSON") { importing = true }
        if let latest = AutomaticBackups.latestFile() {
            ShareLink(item: latest) {
                Label("Сохранить автоматическую копию в Файлы", systemImage: "square.and.arrow.up")
            }
            Text("Автокопии: \(AutomaticBackups.snapshots().count) · хранятся на этом iPhone")
                .font(.caption).foregroundStyle(.secondary)
        }
        Text("Автосохранение выполняется после изменений, архив хранит до 20 снимков. Для сохранения при удалении приложения перенеси JSON в «Файлы» / iCloud Drive.")
            .font(.caption).foregroundStyle(.secondary)
        if !message.isEmpty { Text(message).font(.caption) }
        Text("Восстановление заменяет текущие данные. Сохрани копию перед импортом.").font(.caption).foregroundStyle(.secondary)
        .fileExporter(isPresented: $exportingJSON, document: ShiftBackupDocument(data: store.data), contentType: .json, defaultFilename: "Shiftly-backup") { _ in }
        .fileExporter(isPresented: $exportingCSV, document: ShiftCSVDocument(data: store.data), contentType: .commaSeparatedText, defaultFilename: "Shiftly-export") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else { message = "Нет доступа к файлу"; return }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try JSONDecoder().decode(ShiftData.self, from: Data(contentsOf: url))
                store.replaceData(data)
                message = "Данные восстановлены"
            } catch { message = "Ошибка импорта: \(error.localizedDescription)" }
        }
    }
}
