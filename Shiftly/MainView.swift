import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let violet = Color(red: 0.70, green: 0.43, blue: 0.98)

struct MainView: View {
    @EnvironmentObject var store: ShiftStore
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }

    private var tabs: some View {
        TabView {
            HomeView().tabItem { Label("Главная", systemImage: "house.fill") }
            StatsView().tabItem { Label("Статистика", systemImage: "chart.bar.fill") }
            CalendarView().tabItem { Label("График", systemImage: "calendar") }
            PayrollView().tabItem { Label("Зарплата", systemImage: "rublesign.circle") }
            MoreView().tabItem { Label("Ещё", systemImage: "square.grid.2x2.fill") }
        }
        .background(ShiftlyBackdrop())
        .tint(palette.accent)
    }

    @ViewBuilder var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Native floating Liquid Glass tab bar; avoid a custom bar that
            // would interfere with iOS safe areas and navigation gestures.
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }
}

struct MoreView: View {
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var accent: Color { (ShiftlyPalette(rawValue: themeName) ?? .violet).accent }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    ShiftlySectionHeader(title: "Журнал и история")
                    NavigationLink { HistoryView() } label: {
                        ShiftlyMenuRow(symbol: "clock.arrow.circlepath", title: "История", subtitle: "Перекуры и отчёты", accent: accent)
                    }
                    NavigationLink { LineJournalView() } label: {
                        ShiftlyMenuRow(symbol: "wrench.adjustable.fill", title: "Журнал линии", subtitle: "Заметки оператора", accent: .orange)
                    }
                    ShiftlySectionHeader(title: "Отдых")
                        .padding(.top, 8)
                    NavigationLink { BreakHubView() } label: {
                        ShiftlyMenuRow(symbol: "cup.and.saucer.fill", title: "Центр перекуров", subtitle: "Лимиты, исправления и история", accent: .pink)
                    }
                    ShiftlySectionHeader(title: "Приложение")
                        .padding(.top, 8)
                    NavigationLink { BackupCenterView() } label: {
                        ShiftlyMenuRow(symbol: "externaldrive.fill", title: "Резервные копии", subtitle: "Найти JSON и восстановить", accent: .green)
                    }
                    NavigationLink { SettingsView() } label: {
                        ShiftlyMenuRow(symbol: "paintpalette.fill", title: "Настройки", subtitle: "Оформление и параметры", accent: accent)
                    }
                    Text("Shiftly · Operator Edition")
                        .font(.caption2).foregroundStyle(.white.opacity(0.52))
                        .frame(maxWidth: .infinity).padding(.top, 12)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .scrollIndicators(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
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
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("shiftly.motion") private var motionEnabled = true
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var accent: Color { (ShiftlyPalette(rawValue: themeName) ?? .violet).accent }

    private var asset: String {
        if mode == 0 { return "MascotDone" }
        if mode == 2 && remainingSingle > 120 { return "MascotBreak" }
        return "MascotWork"
    }
    private var stage: String {
        guard mode == 2 else { return mode == 1 ? "РАБОЧИЙ НАСТРОЙ" : "ВРЕМЯ ОТДЫХАТЬ" }
        if remainingSingle <= 0 { return "ВРЕМЯ ВЫШЛО" }
        if remainingSingle <= 60 { return "ОСТАЛАСЬ МИНУТА" }
        if remainingSingle <= 120 { return "ПОРА ВОЗВРАЩАТЬСЯ" }
        if remainingSingle <= 300 { return "СКОРО ОБРАТНО" }
        return "КОФЕЙНАЯ ПАУЗА"
    }
    private var caption: String {
        if tapped { return mode == 2 ? "Я слежу за твоими минутами 💜" : mode == 1 ? "Сегодня всё получится!" : "Увидимся на смене 💜" }
        if mode == 2 && remainingSingle <= 0 { return "Эй, пора обратно! ⏰" }
        if mode == 2 && remainingSingle <= 60 { return "Последняя минутка ☕" }
        if mode == 2 && remainingSingle <= 300 { return "Допивай кофе, скоро работать 💜" }
        return mode == 2 ? "Заслуженный перерыв ☕" : mode == 1 ? "Смена в деле!" : "Отдыхай, оператор 💜"
    }
    var body: some View {
        let height: CGFloat = compact ? 104 : 160
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [accent.opacity(0.12), .clear, .black.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(asset)
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity).frame(height: height + 8)
                .offset(y: hovering ? -5 : 3)
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, .black.opacity(0.90)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: mode == 2 && remainingSingle < 60 ? "exclamationmark.circle.fill" : "sparkles")
                        .symbolEffect(.pulse, options: .repeating)
                    Text(stage).tracking(1.2)
                }
                .font(.caption2.bold())
                .foregroundStyle(mode == 2 && remainingSingle < 60 ? .orange : accent)
                Text(caption)
                    .font(compact ? .subheadline : .headline)
                    .lineLimit(2)
            }.padding(16)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shiftlyGlass(radius: 24, emphasis: true)
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { tapped.toggle() }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .onAppear {
            if motionEnabled && !reduceMotion {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { hovering = true }
            }
        }
        .accessibilityLabel("Операторша. " + caption)
    }
}


struct HomeView: View {
    @EnvironmentObject var store: ShiftStore
    @AppStorage("shiftly.compactHome") private var compact = false
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    @State private var showQuickPastBreak = false
    @State private var showFocus = false
    @State private var confirmEnd = false
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var recentSession: WorkSession? {
        store.current ?? store.data.sessions.max(by: { $0.start < $1.start })
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let session = store.current
                let active = session?.breaks.last(where: { $0.end == nil })
                let singleRemaining = active.map { Double(store.perBreakLimitMinutes * 60) - now.timeIntervalSince($0.start) }
                    ?? Double(store.perBreakLimitMinutes * 60)
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session == nil ? "ВЫХОДНОЙ" : store.isOnBreak ? "ВРЕМЯ ОТДЫХА" : "ТВОЯ СМЕНА")
                                    .font(.caption2.bold()).tracking(1.6).foregroundStyle(palette.accent)
                                Text(session == nil ? "Отдыхай 💜" : store.isOnBreak ? "Перекур" : "Всё под контролем")
                                    .font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            }
                            Spacer()
                            Button { withAnimation(.easeInOut(duration: 0.2)) { compact.toggle() } } label: {
                                Image(systemName: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                    .font(.subheadline.bold()).foregroundStyle(.white)
                                    .frame(width: 42, height: 42).shiftlyGlassControl(radius: 14)
                            }
                            .accessibilityLabel(compact ? "Расширенный интерфейс" : "Компактный интерфейс")
                        }

                        MascotPanel(mode: session == nil ? 0 : store.isOnBreak ? 2 : 1,
                                    remainingSingle: singleRemaining, compact: compact)

                        if let session {
                            let spent = store.breakSeconds(session, now: now)
                            let totalRemaining = Double(session.breakLimitMinutes * 60) - spent
                            let untilEnd = max(0, (session.end ?? session.start.addingTimeInterval(12 * 3600)).timeIntervalSince(now))
                            VStack(alignment: .leading, spacing: 13) {
                                HStack {
                                    Label(store.isOnBreak ? "Перекур активен" : "Смена идёт", systemImage: store.isOnBreak ? "cup.and.saucer.fill" : "briefcase.fill")
                                        .font(.subheadline.bold()).foregroundStyle(palette.accent)
                                    Spacer()
                                    Text("С " + ruDate(session.start)).font(.caption2)
                                        .foregroundStyle(Color.white.opacity(0.76)).lineLimit(1).minimumScaleFactor(0.65)
                                }
                                HStack(spacing: 10) {
                                    ShiftRing(remaining: store.isOnBreak ? singleRemaining : untilEnd,
                                              total: store.isOnBreak ? Double(store.perBreakLimitMinutes * 60) : 12 * 3600,
                                              subtitle: store.isOnBreak ? "ТЕКУЩИЙ ПЕРЕКУР" : "ДО КОНЦА СМЕНЫ", compact: true)
                                        .frame(maxWidth: .infinity)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("ОСТАТОК ОТДЫХА").font(.caption2.bold()).tracking(0.8)
                                            .foregroundStyle(Color.white.opacity(0.75))
                                        Text(timeString(max(0, totalRemaining)))
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                                        ProgressView(value: min(1, max(0, totalRemaining / Double(max(1, session.breakLimitMinutes * 60)))))
                                            .tint(totalRemaining < 300 ? .orange : palette.accent)
                                        Text("До конца смены: " + timeString(untilEnd))
                                            .font(.caption).foregroundStyle(Color.white.opacity(0.76))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                HStack(spacing: 10) {
                                    ShiftlyStatChip(symbol: "briefcase.fill", title: "Работа", value: timeString(store.workSeconds(session, now: now)))
                                    ShiftlyStatChip(symbol: "cup.and.saucer.fill", title: "Отдых", value: timeString(spent))
                                }
                                Text(RestForecast.message(remaining: totalRemaining, minutesPerBreak: store.perBreakLimitMinutes,
                                                          untilShiftEnd: untilEnd, active: store.isOnBreak))
                                    .font(.caption).foregroundStyle(Color.white.opacity(0.76))
                                if totalRemaining < 0 {
                                    Label("Превышен лимит: " + timeString(-totalRemaining), systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange).font(.caption.bold())
                                }
                            }
                            .padding(16)
                            .shiftlyGlass(radius: 24, emphasis: true)

                            Button { store.toggleBreak(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() } label: {
                                Label(store.isOnBreak ? "Вернулся к работе" : "Начать перекур",
                                      systemImage: store.isOnBreak ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                            }
                            .buttonStyle(ShiftlyPrimaryButtonStyle())

                            HStack(spacing: 11) {
                                Button { showQuickPastBreak = true } label: {
                                    Label("Забытый перекур", systemImage: "clock.arrow.circlepath")
                                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                                        .shiftlyGlassControl(radius: 15)
                                }
                                Button { showFocus = true } label: {
                                    Label("Фокус", systemImage: "scope")
                                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                                        .shiftlyGlassControl(radius: 15)
                                }
                            }
                            .foregroundStyle(.white)
                            if !compact {
                                Button("Завершить смену", role: .destructive) { confirmEnd = true }
                                    .font(.caption).frame(maxWidth: .infinity).padding(.top, 4)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Сегодня нет активной смены").font(.headline).foregroundStyle(.white)
                                Text("График отслеживается автоматически. Внеплановую смену можно запустить вручную.")
                                    .font(.subheadline).foregroundStyle(Color.white.opacity(0.74))
                                Button("Начать внеплановую смену") { store.startWork() }
                                    .buttonStyle(ShiftlyPrimaryButtonStyle())
                            }.padding(17).shiftlyGlass(radius: 22)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .background(ShiftlyBackdrop())
            }
            .navigationTitle("Shiftly")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFocus) { ShiftlyFocusView() }
            .sheet(isPresented: $showQuickPastBreak) {
                if let session = recentSession { QuickPastBreakEditor(sessionID: session.id) }
                else { NavigationStack { BreakHubView() } }
            }
            .confirmationDialog("Завершить смену?", isPresented: $confirmEnd) {
                Button("Завершить смену", role: .destructive) { store.endWork() }
                Button("Отмена", role: .cancel) { }
            } message: { Text("Это закроет текущую смену и остановит перекур.") }
        }
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
                let rested = sessions.reduce(0.0) { $0 + store.breakSeconds($1) }
                let allBreaks = sessions.flatMap(\.breaks)
                let average = allBreaks.isEmpty ? 0 : Int(rested / Double(allBreaks.count) / 60)
                let within = completed.filter { store.breakSeconds($0) <= Double($0.breakLimitMinutes * 60) }.count
                let day = sessions.filter { Calendar.current.component(.hour, from: $0.start) < 14 }
                let night = sessions.filter { Calendar.current.component(.hour, from: $0.start) >= 14 }
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.headline).foregroundStyle(.white)
                        Spacer()
                        Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(14).shiftlyGlass(radius: 17)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                        stat("Отработано", String(format: "%.1f ч", hours), "briefcase.fill")
                        stat("Отдых", String(format: "%.1f ч", rested / 3600), "cup.and.saucer.fill")
                        stat("Средний перекур", "\(average) мин", "timer")
                        stat("Количество", "\(allBreaks.count)", "number")
                    }
                    ShiftlySectionHeader(title: "Перекуры за неделю")
                    ShiftlyWeekBars(sessions: store.data.sessions)
                    ShiftlySectionHeader(title: "День и ночь")
                    comparison("Дневные", sessions: day, color: .green)
                    comparison("Ночные", sessions: night, color: .purple)
                    ShiftlySectionHeader(title: "Лимиты и достижения")
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("В пределах лимита"); Spacer(); Text("\(within) / \(completed.count)").bold() }
                            .font(.subheadline).foregroundStyle(.white)
                        ProgressView(value: Double(within), total: Double(max(1, completed.count))).tint(violet)
                        achievement("Первая смена", unlocked: completed.count >= 1, progress: completed.count, goal: 1)
                        achievement("Режим завода", unlocked: completed.count >= 10, progress: completed.count, goal: 10)
                        achievement("Дисциплина", unlocked: within >= 5, progress: within, goal: 5)
                    }
                    .padding(14).shiftlyGlass(radius: 20)
                    Text("Данные пересчитываются по фактически прошедшему времени.")
                        .font(.caption).foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(16).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("Статистика")
        }
    }
    func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(Color.white.opacity(0.73))
            Text(value).font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(15).shiftlyGlass(radius: 18)
    }
    func comparison(_ title: String, sessions: [WorkSession], color: Color) -> some View {
        let seconds = sessions.reduce(0.0) { $0 + store.breakSeconds($1) }
        let allowance = sessions.reduce(0.0) { $0 + Double($1.breakLimitMinutes * 60) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title); Spacer(); Text("\(sessions.count) смен · \(Int(seconds / 60)) мин") }
                .font(.subheadline)
            ProgressView(value: min(1, seconds / max(1, allowance))).tint(color)
        }.padding().shiftlyGlass(radius: 18)
    }
    func achievement(_ name: String, unlocked: Bool, progress: Int, goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: unlocked ? "trophy.fill" : "lock.fill").foregroundStyle(unlocked ? .yellow : .secondary); Text(name); Spacer(); Text("\(min(progress,goal))/\(goal)").foregroundStyle(.secondary) }
            ProgressView(value: Double(min(progress,goal)), total: Double(goal)).tint(violet)
        }.padding(.vertical, 4)
    }
}

struct PayrollView: View {
    @EnvironmentObject var store: ShiftStore
    @StateObject private var pay = PayrollSettings()
    @State private var month = Date()
    @AppStorage("shiftly.salaryGoal") private var salaryGoal = 120_000.0
    var body: some View {
        NavigationStack {
            ScrollView {
                let result = payroll(for: store, settings: pay, month: month)
                let forecast = PayrollProjection.calculate(store: store, settings: pay, month: month)
                VStack(alignment: .leading, spacing: 14) {
                    DatePicker("Месяц", selection: $month, displayedComponents: .date)
                        .padding(14).shiftlyGlass(radius: 18)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ПРОГНОЗ ЗАРПЛАТЫ")
                            .font(.caption2.bold()).tracking(1.4).foregroundStyle(.white.opacity(0.73))
                        Text(forecast.total, format: .currency(code: "RUB"))
                            .font(.system(size: 33, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
                        HStack {
                            Text("Уже начислено · оценка")
                            Spacer()
                            Text(result.estimated, format: .currency(code: "RUB"))
                        }.font(.subheadline).foregroundStyle(.white.opacity(0.80))
                        ProgressView(value: min(1, max(0, forecast.total / max(1, salaryGoal)))).tint(violet)
                        Text("Осталось по графику: \(forecast.upcomingShifts) смен")
                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(18).shiftlyGlass(radius: 23, emphasis: true)
                    ShiftlySectionHeader(title: "Отработанное время")
                    VStack(spacing: 12) {
                        payRow("Учтено рабочих часов", String(format: "%.1f ч", result.normalHours))
                        payRow("Ночные часы (22–06)", String(format: "%.1f ч", result.nightHours))
                        payRow("Подработки без записи", String(format: "%.1f ч", result.overtimeHours))
                        payRow("Будущие смены · оценка", forecast.future.formatted(.currency(code: "RUB")))
                    }
                    .padding(16).shiftlyGlass(radius: 20)
                    ShiftlySectionHeader(title: "Ставки и цель")
                    VStack(spacing: 14) {
                        payInput("Цель за месяц, ₽", value: $salaryGoal, width: 122)
                        payInput("₽ за час", value: $pay.hourlyRate, width: 100)
                        payInput("Ночные ×", value: $pay.nightMultiplier, width: 90)
                        payInput("Подработка ×", value: $pay.overtimeMultiplier, width: 90)
                        payInput("Премия, ₽", value: $pay.monthlyBonus, width: 100)
                    }
                    .padding(16).shiftlyGlass(radius: 20)
                    Text("Расчёт предварительный: будущие смены считаются по 12 часов. Налоги, премиальные условия и правила предприятия могут изменить итог.")
                        .font(.caption).foregroundStyle(Color.white.opacity(0.73))
                }
                .frame(maxWidth: .infinity).padding(16)
            }
            .scrollIndicators(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("Зарплата")
        }
    }
    private func payRow(_ name: String, _ amount: String) -> some View {
        HStack(spacing: 12) {
            Text(name).foregroundStyle(.white.opacity(0.82))
            Spacer(minLength: 8)
            Text(amount).foregroundStyle(.white).bold().lineLimit(1).minimumScaleFactor(0.7)
        }.font(.subheadline)
    }
    private func payInput(_ title: String, value: Binding<Double>, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text(title).foregroundStyle(.white.opacity(0.84))
            Spacer(minLength: 8)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
        }.font(.subheadline)
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 5) {
                        ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                        ForEach(0..<leadingBlanks(), id: \.self) { _ in Color.clear.frame(height: 55) }
                        ForEach(days, id: \.self) { day in
                            let label = store.dayLabel(day)
                            let hasExtra = store.data.extras.contains { Calendar.current.isDate($0.start, inSameDayAs: day) }
                            let breakMinutes = store.data.sessions.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
                                .reduce(0.0) { $0 + store.breakSeconds($1) / 60 }
                            VStack(spacing: 4) {
                                Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                                Text(label).font(.caption.bold()).foregroundStyle(label == "Н" ? .purple : label == "Д" ? .green : .secondary)
                                if hasExtra { Circle().fill(.orange).frame(width: 6, height: 6) }
                                if breakMinutes > 0 {
                                    Capsule().fill(Color.pink.opacity(min(1, 0.3 + breakMinutes / 150)))
                                        .frame(width: 21, height: 3)
                                }
                            }.frame(maxWidth: .infinity).frame(height: 52)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Calendar.current.isDateInToday(day) ? Color.purple : Color.clear, lineWidth: 1.5))
                        }
                    }
                    Text("Д — день 08–20 · Н — ночь 20–08 · В — выходной · розовая полоска — отдых")
                        .font(.caption).foregroundStyle(.secondary)
                    NavigationLink { NextShiftView() } label: {
                        ShiftlyMenuRow(symbol: "calendar", title: "Следующая смена", subtitle: "Время до выхода на работу", accent: .cyan)
                    }.buttonStyle(.plain)
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
                    Text("Проверка правила 42 часов требует уточнения условий предприятия.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden).background(ShiftlyBackdrop()).navigationTitle("График")
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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(store.data.sessions.sorted(by: { $0.start > $1.start }))) { session in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 6) {
                                Image(systemName: session.end == nil ? "clock.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(session.end == nil ? .purple : .green)
                                Text(ruDate(session.start)).font(.subheadline.bold()).foregroundStyle(.white)
                                Spacer()
                            }
                            Text(session.end == nil ? "Смена идёт" : "Смена завершена")
                                .font(.caption).foregroundStyle(Color.white.opacity(0.75))
                            HStack {
                                Label(timeString(store.workSeconds(session)), systemImage: "briefcase.fill")
                                Spacer(minLength: 8)
                                Label(timeString(store.breakSeconds(session)), systemImage: "cup.and.saucer.fill")
                            }.font(.caption).foregroundStyle(.white.opacity(0.86))
                            HStack(spacing: 12) {
                                NavigationLink { SessionEditor(sessionID: session.id) } label: {
                                    Label("Исправить", systemImage: "pencil")
                                }
                                Spacer()
                                NavigationLink { ShiftReportView(sessionID: session.id) } label: {
                                    Label("Отчёт", systemImage: "doc.text")
                                }
                            }.font(.subheadline.bold())
                        }
                        .padding(15).shiftlyGlass(radius: 19)
                    }
                    if store.data.sessions.isEmpty {
                        Text("Смен пока нет").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(18).shiftlyGlass(radius: 18)
                    }
                }
                .padding(16).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("История")
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: ShiftStore
    @ObservedObject private var live = LiveDiagnostics.shared
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    @AppStorage("shiftly.motion") private var motionEnabled = true
    @AppStorage("shiftly.neonNight") private var neonNight = true
    @AppStorage("shiftly.compactHome") private var compactHome = false
    var body: some View {
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
                Section("Liquid Glass · оформление") {
                    Picker("Цветовая тема", selection: $themeName) {
                        ForEach(ShiftlyPalette.allCases) { palette in
                            Text(palette.label).tag(palette.rawValue)
                        }
                    }
                    HStack(spacing: 13) {
                        ForEach(ShiftlyPalette.allCases) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { themeName = palette.rawValue }
                            } label: {
                                Circle()
                                    .fill(LinearGradient(colors: [palette.accent, palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(.white.opacity(themeName == palette.rawValue ? 0.9 : 0.0), lineWidth: 2.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(palette.label)
                        }
                    }
                    Toggle("Неоновый ночной градиент", isOn: $neonNight)
                    Toggle("Плавные анимации", isOn: $motionEnabled)
                    Toggle("Компактная главная панель", isOn: $compactHome)
                    if #available(iOS 26.0, *) {
                        Text("Настоящий Liquid Glass доступен на этом iPhone")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("На этой версии iOS используется полупрозрачный стиль с системным материалом")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Dynamic Island · диагностика") {
                    Text("Разрешены системой: \(live.enabled ? "да" : "нет")")
                    Text(live.status).font(.caption).textSelection(.enabled)
                    Text("Запусти смену и перекур, затем проверь этот статус.").font(.caption).foregroundStyle(.secondary)
                }
                Section("О приложении") {
                    Text("Shiftly \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · сборка \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")")
                    Text("Данные хранятся локально на устройстве.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("Настройки")
    }
}

struct ShiftRing: View {
    let remaining: Double
    let total: Double
    let subtitle: String
    var compact: Bool = false
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var fraction: CGFloat { CGFloat(min(1, max(0, remaining / max(1, total)))) }
    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).padding(13)
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1).padding(13))
            Circle().stroke(palette.accent.opacity(0.13), lineWidth: 14)
            Circle().trim(from: 0, to: fraction)
                .stroke(AngularGradient(colors: [palette.accent, palette.secondary, .pink, palette.accent], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: palette.accent.opacity(0.65), radius: 10)
                .animation(.easeInOut(duration: 0.6), value: Int(remaining))
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.caption).foregroundStyle(palette.accent)
                Text(subtitle)
                    .font(.caption2.bold()).tracking(1)
                    .foregroundStyle(.secondary)
                Text(remaining < 0 ? "+" + timeString(-remaining) : timeString(remaining))
                    .font(.system(size: compact ? 23 : 31, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.62).lineLimit(1)
                    .foregroundStyle(remaining < 0 ? .orange : .white)
                Text("SHIFTLY")
                    .font(.caption2.bold()).tracking(1.4)
                    .foregroundStyle(palette.accent)
            }
            .padding(18)
        }
        .frame(width: compact ? 146 : 208, height: compact ? 146 : 208)
        .padding(.vertical, compact ? 2 : 8)
        .accessibilityElement(children: .combine)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                ShiftlySectionHeader(title: "Новая запись")
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Ручей", selection: $stream) {
                        ForEach(["910", "911", "912", "Другой"], id: \.self) { Text($0) }
                    }
                    Picker("Событие", selection: $category) {
                        ForEach(["Заметка", "Остановка", "Ремонт", "Переналадка", "Замена рулона", "Запуск"], id: \.self) { Text($0) }
                    }
                    TextField("Что произошло?", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(12)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    Stepper("Простой: \(duration) мин", value: $duration, in: 0...720, step: 1)
                    Button {
                        store.addNote(LineNote(date: Date(), stream: stream, category: category,
                                               details: details, durationMinutes: duration))
                        details = ""; duration = 0
                    } label: {
                        Label("Добавить запись", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(ShiftlyPrimaryButtonStyle())
                    .disabled(details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16).shiftlyGlass(radius: 20)
                ShiftlySectionHeader(title: "История событий")
                if store.notes.isEmpty {
                    Text("Записей пока нет").foregroundStyle(.white.opacity(0.73))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
                        .shiftlyGlass(radius: 18)
                }
                ForEach(store.notes.sorted(by: { $0.date > $1.date })) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(note.category) · ручей \(note.stream)")
                                .font(.subheadline.bold()).foregroundStyle(.white)
                            Spacer()
                            if note.durationMinutes > 0 {
                                Text("\(note.durationMinutes) мин").font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text(note.details).font(.subheadline).foregroundStyle(.white.opacity(0.84))
                        Text(ruDate(note.date)).font(.caption2)
                            .foregroundStyle(.white.opacity(0.67))
                        HStack {
                            Button("Изменить") { editing = note }
                            Spacer()
                            Button("Удалить", role: .destructive) { store.removeNote(note.id) }
                        }
                        .font(.caption.bold())
                    }
                    .padding(15).shiftlyGlass(radius: 19)
                }
            }
            .padding(16).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(ShiftlyBackdrop())
        .navigationTitle("Журнал линии")
        .sheet(item: $editing) { note in NoteEditor(note: note) }
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
            .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Редактирование")
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
        .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Корректировка")
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
            .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Добавить перекур")
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
        .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Исправить перекур")
        .onAppear { if !ready { start = item.start; end = item.end ?? Date(); ready = true } }
    }
}

