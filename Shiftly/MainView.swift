import SwiftUI

private let violet = Color(red: 0.70, green: 0.43, blue: 0.98)

struct MainView: View {
    @EnvironmentObject var store: ShiftStore
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Главная", systemImage: "house.fill") }
            StatsView().tabItem { Label("Статистика", systemImage: "chart.bar.fill") }
            CalendarView().tabItem { Label("График", systemImage: "calendar") }
            PayrollView().tabItem { Label("Зарплата", systemImage: "rublesign.circle") }
            HistoryView().tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
            SettingsView().tabItem { Label("Настройки", systemImage: "gearshape") }
        }
    }
}

func timeString(_ seconds: TimeInterval) -> String {
    let n = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", n / 3600, (n / 60) % 60, n % 60)
}

struct MascotPanel: View {
    let mode: Int // 0 off, 1 work, 2 break
    @State private var tapped = false
    private var asset: String { mode == 2 ? "MascotBreak" : mode == 1 ? "MascotWork" : "MascotDone" }
    private var caption: String {
        if tapped { return mode == 2 ? "Отдыхай, я слежу за временем 💜" : mode == 1 ? "Держим темп, оператор!" : "Ты заслужил отдых 💜" }
        return mode == 2 ? "Наконец-то перерыв ☕" : mode == 1 ? "Смена в деле!" : "До следующей смены отдыхаем"
    }
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(asset).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 232)
            LinearGradient(colors: [.clear, .black.opacity(0.86)], startPoint: .center, endPoint: .bottom)
            Text(caption).font(.headline).padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(violet.opacity(0.6), lineWidth: 1))
        .onTapGesture { tapped.toggle() }
        .accessibilityLabel("Операторша. " + caption)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: ShiftStore
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                ScrollView {
                    VStack(spacing: 14) {
                        MascotPanel(mode: store.current == nil ? 0 : store.isOnBreak ? 2 : 1)
                        if let s = store.current {
                            let spent = store.breakSeconds(s, now: now)
                            let remaining = Double(s.breakLimitMinutes * 60) - spent
                            VStack(spacing: 10) {
                                Label(store.isOnBreak ? "Перерыв" : "Смена идёт", systemImage: store.isOnBreak ? "cup.and.saucer.fill" : "briefcase.fill")
                                    .font(.headline).foregroundStyle(violet)
                                Text(timeString(store.isOnBreak ? max(0, remaining) : max(0, 12*3600 - now.timeIntervalSince(s.start))))
                                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                                Text(store.isOnBreak ? "Осталось из лимита перерывов" : "Осталось до 12 часов с начала смены")
                                    .font(.caption).foregroundStyle(.secondary)
                                ProgressView(value: min(1, spent / Double(max(1, s.breakLimitMinutes * 60)))).tint(violet)
                                HStack {
                                    metric("Работа", timeString(store.workSeconds(s, now: now)))
                                    metric("Перерывы", timeString(spent))
                                }
                                if remaining < 0 { Text("Лимит превышен на " + timeString(-remaining)).foregroundStyle(.red).font(.caption) }
                            }.padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            Button(store.isOnBreak ? "Вернуться к работе" : "Начать перерыв") { store.toggleBreak() }
                                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                            Button("Завершить смену", role: .destructive) { store.endWork() }.padding(.top, 4)
                        } else {
                            Text("Смена не запущена").font(.title2.bold())
                            Text("Запускай учёт вручную в начале работы").foregroundStyle(.secondary)
                            Button("Начать смену") { store.startWork() }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }.padding()
                }
            }.navigationTitle("Shiftly")
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
                let breaks = sessions.reduce(0.0) { $0 + store.breakSeconds($1) } / 3600
                let within = completed.filter { store.breakSeconds($0) <= Double($0.breakLimitMinutes * 60) }.count
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.headline); Spacer()
                        Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                    }
                    stat("Отработано", String(format: "%.1f ч", hours), "clock.fill")
                    stat("Перерывы", String(format: "%.1f ч", breaks), "cup.and.saucer.fill")
                    stat("Смены", "\(completed.count) завершено", "calendar.badge.checkmark")
                    Text("Достижения").font(.title2.bold())
                    achievement("Первая смена", unlocked: completed.count >= 1, progress: completed.count, goal: 1)
                    achievement("Режим завода", unlocked: completed.count >= 10, progress: completed.count, goal: 10)
                    achievement("Дисциплина", unlocked: within >= 5, progress: within, goal: 5)
                    Text("Достижения считаются по завершённым сменам выбранного месяца.").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Статистика")
        }
    }
    func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack { Image(systemName: symbol).foregroundStyle(violet).frame(width: 32); Text(title); Spacer(); Text(value).bold() }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                            Text(extra.start.formatted(date: .abbreviated, time: .shortened))
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
                    Text(session.start.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                    Text(session.end == nil ? "Смена продолжается" : "Завершена").foregroundStyle(.secondary)
                    Text("Работа: \(timeString(store.workSeconds(session))) · Перекуры: \(timeString(store.breakSeconds(session)))")
                        .font(.caption).monospacedDigit()
                    Text("Лимит: \(session.breakLimitMinutes) мин · Перекуров: \(session.breaks.count)").font(.caption).foregroundStyle(.secondary)
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
                Section("График") {
                    Text("2 дня → выходной → 2 ночи → 3 выходных")
                    Text("Опорная дата: 4 ноября 2026 — первая ночь").font(.caption).foregroundStyle(.secondary)
                }
                Section("Dynamic Island · диагностика") {
                    Text("Разрешены системой: \(live.enabled ? "да" : "нет")")
                    Text(live.status).font(.caption).textSelection(.enabled)
                    Text("Запусти смену и перекур, затем проверь этот статус.").font(.caption).foregroundStyle(.secondary)
                }
                Section("О приложении") {
                    Text("Shiftly \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · сборка \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")")
                    Text("Версия IPA: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    Text("Данные хранятся локально на устройстве.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Настройки")
        }
    }
}
