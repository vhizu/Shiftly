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
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("SHIFTLY 1.8", systemImage: "sparkles")
                            .font(.caption.bold()).tracking(2).foregroundStyle(accent)
                        Text("Твоё пространство").font(.system(size: 31, weight: .bold, design: .rounded))
                        Text("Всё для смен, отдыха и спокойной головы")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .shiftlyGlass(radius: 26, emphasis: true)

                    NavigationLink { HistoryView() } label: {
                        ShiftlyQuickTile(symbol: "clock.arrow.circlepath", title: "История", detail: "Перекуры и отчёты", accent: accent)
                    }
                    NavigationLink { LineJournalView() } label: {
                        ShiftlyQuickTile(symbol: "wrench.adjustable.fill", title: "Журнал линии", detail: "Записи оператора", accent: .orange)
                    }
                    NavigationLink { NextShiftView() } label: {
                        ShiftlyQuickTile(symbol: "calendar.badge.clock", title: "Следующая смена", detail: "План и отсчёт", accent: .cyan)
                    }
                    NavigationLink { BreakHubView() } label: {
                        ShiftlyQuickTile(symbol: "cup.and.saucer.fill", title: "Центр перекуров", detail: "Записи и лимиты", accent: .pink)
                    }
                    NavigationLink { BackupCenterView() } label: {
                        ShiftlyQuickTile(symbol: "externaldrive.fill.badge.timemachine", title: "Резервные копии", detail: "Экспорт и восстановление", accent: .green)
                    }
                    NavigationLink { SettingsView() } label: {
                        ShiftlyQuickTile(symbol: "paintpalette.fill", title: "Настройки", detail: "Темы и параметры", accent: accent)
                    }
                }
                .padding(17)
            }
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
        let height: CGFloat = compact ? 116 : 225
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
    @State private var showBreakHub = false
    @State private var showNextShift = false
    @State private var showQuickPastBreak = false
    @State private var showFocus = false
    @State private var showBackup = false
    @State private var showReport = false
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var recentSession: WorkSession? {
        store.current ?? store.data.sessions.max(by: { $0.start < $1.start })
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let active = store.current?.breaks.last(where: { $0.end == nil })
                let singleRemaining = active.map { Double(store.perBreakLimitMinutes * 60) - now.timeIntervalSince($0.start) }
                    ?? Double(store.perBreakLimitMinutes * 60)
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("ТВОЯ СМЕНА · SHIFTLY")
                                    .font(.caption2.bold()).tracking(2).foregroundStyle(palette.accent)
                                Text(store.current == nil ? "Время для себя" : store.isOnBreak ? "Отдыхай 💜" : "Всё под контролем")
                                    .font(.system(size: compact ? 25 : 30, weight: .bold, design: .rounded))
                                Text(ruDate(now)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 5)
                            Button { compact.toggle() } label: {
                                Image(systemName: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                    .font(.headline)
                                    .frame(width: 46, height: 46)
                                    .shiftlyGlass(radius: 15)
                            }
                            .accessibilityLabel(compact ? "Крупный интерфейс" : "Компактный интерфейс")
                        }
                        MascotPanel(mode: store.current == nil ? 0 : store.isOnBreak ? 2 : 1,
                                    remainingSingle: singleRemaining, compact: compact)
                        if let session = store.current {
                            let spent = store.breakSeconds(session, now: now)
                            let totalRemaining = Double(session.breakLimitMinutes * 60) - spent
                            let untilEnd = max(0, (session.end ?? session.start.addingTimeInterval(12 * 3600)).timeIntervalSince(now))
                            VStack(spacing: compact ? 12 : 17) {
                                HStack {
                                    Label(store.isOnBreak ? "Идёт перекур" : "Смена идёт", systemImage: store.isOnBreak ? "cup.and.saucer.fill" : "moon.stars.fill")
                                        .font(.subheadline.bold()).foregroundStyle(palette.accent)
                                    Spacer()
                                    Text("Начало " + ruDate(session.start))
                                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                ShiftRing(remaining: store.isOnBreak ? singleRemaining : untilEnd,
                                          total: store.isOnBreak ? Double(store.perBreakLimitMinutes * 60) : 12 * 3600,
                                          subtitle: store.isOnBreak ? "ТЕКУЩИЙ ПЕРЕКУР" : "ДО КОНЦА СМЕНЫ",
                                          compact: compact)
                                VStack(spacing: 9) {
                                    HStack {
                                        Text("ОБЩИЙ ЛИМИТ ОТДЫХА")
                                            .font(.caption2.bold()).tracking(0.9).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(timeString(max(0, totalRemaining)))
                                            .font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
                                    }
                                    ProgressView(value: min(1, max(0, totalRemaining / Double(max(1, session.breakLimitMinutes * 60)))))
                                        .tint(totalRemaining < 300 ? .orange : palette.accent)
                                    Text(RestForecast.message(remaining: totalRemaining,
                                        minutesPerBreak: store.perBreakLimitMinutes, untilShiftEnd: untilEnd,
                                        active: store.isOnBreak))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                HStack(spacing: 11) {
                                    ShiftlyStatChip(symbol: "briefcase.fill", title: "Работа", value: timeString(store.workSeconds(session, now: now)))
                                    ShiftlyStatChip(symbol: "cup.and.saucer.fill", title: "Отдых", value: timeString(spent))
                                }
                                if totalRemaining < 0 {
                                    Label("Лимит превышен на " + timeString(-totalRemaining), systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange).font(.caption.bold())
                                }
                            }
                            .padding(compact ? 14 : 18)
                            .shiftlyGlass(radius: 27, emphasis: true)

                            Button { store.toggleBreak(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() } label: {
                                Label(store.isOnBreak ? "Вернулся к работе" : "Начать перекур", systemImage: store.isOnBreak ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                            }
                            .buttonStyle(ShiftlyPrimaryButtonStyle())

                            HStack(spacing: 12) {
                                Button { showFocus = true } label: {
                                    Label("Фокус", systemImage: "circle.dotted.circle")
                                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                                        .shiftlyGlass(radius: 17)
                                }
                                Button { showReport = true } label: {
                                    Label("Отчёт", systemImage: "chart.bar.doc.horizontal")
                                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                                        .shiftlyGlass(radius: 17)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Сегодня нет активной смены").font(.title3.bold())
                                Text("График определится автоматически. Если вышел вне плана — запусти смену вручную.")
                                    .foregroundStyle(.secondary).font(.subheadline)
                                Button("Начать внеплановую смену") { store.startWork() }
                                    .buttonStyle(ShiftlyPrimaryButtonStyle())
                                if let last = store.data.sessions.filter({ $0.end != nil }).max(by: { $0.start < $1.start }) {
                                    Button { showReport = true } label: {
                                        Label("Итоги последней смены · " + ruDate(last.start), systemImage: "chart.bar.doc.horizontal")
                                            .font(.subheadline).frame(maxWidth: .infinity).padding(12)
                                            .shiftlyGlass(radius: 17)
                                    }
                                }
                            }
                            .padding(19).shiftlyGlass(radius: 24)
                        }
                        Text("БЫСТРЫЕ ДЕЙСТВИЯ")
                            .font(.caption2.bold()).tracking(1.8).foregroundStyle(.secondary).padding(.top, 3)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            Button { showQuickPastBreak = true } label: {
                                ShiftlyQuickTile(symbol: "clock.badge.plus", title: "Забытый перекур", detail: "Записать задним числом", accent: .orange)
                            }
                            Button { showBreakHub = true } label: {
                                ShiftlyQuickTile(symbol: "cup.and.saucer.fill", title: "Центр отдыха", detail: "Лимиты и история", accent: palette.accent)
                            }
                            Button { showNextShift = true } label: {
                                ShiftlyQuickTile(symbol: "calendar.badge.clock", title: "Следующая", detail: "До выхода на смену", accent: .cyan)
                            }
                            Button { showBackup = true } label: {
                                ShiftlyQuickTile(symbol: "externaldrive.fill.badge.timemachine", title: "Бэкапы", detail: "Сохранить историю", accent: .green)
                            }
                        }
                        .buttonStyle(.plain)
                        if let session = recentSession {
                            HStack {
                                Image(systemName: "sparkles").foregroundStyle(palette.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Всё записано").font(.subheadline.bold())
                                    Text("Последняя смена: " + ruDate(session.start))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(session.breaks.count) ☕").font(.subheadline.bold())
                            }
                            .padding(16).shiftlyGlass(radius: 18)
                        }
                        if store.current != nil {
                            Button("Завершить смену", role: .destructive) { store.endWork() }
                                .font(.caption).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(ShiftlyBackdrop())
            }
            .navigationTitle("Shiftly")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBreakHub) { BreakHubView() }
            .sheet(isPresented: $showNextShift) { NextShiftView() }
            .sheet(isPresented: $showFocus) { ShiftlyFocusView() }
            .sheet(isPresented: $showBackup) { NavigationStack { BackupCenterView() } }
            .sheet(isPresented: $showReport) {
                NavigationStack {
                    if let session = recentSession { ShiftReportView(sessionID: session.id) }
                }
            }
            .sheet(isPresented: $showQuickPastBreak) {
                if let session = recentSession { QuickPastBreakEditor(sessionID: session.id) }
                else { BreakHubView() }
            }
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
                    ShiftlyWeekBars(sessions: store.data.sessions)
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
            }.scrollIndicators(.hidden).background(ShiftlyBackdrop()).navigationTitle("Статистика")
        }
    }
    func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack { Image(systemName: symbol).foregroundStyle(violet).frame(width: 32); Text(title); Spacer(); Text(value).bold() }
            .padding().shiftlyGlass(radius: 18)
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
        }.padding().shiftlyGlass(radius: 18)
    }
}

struct PayrollView: View {
    @EnvironmentObject var store: ShiftStore
    @StateObject private var pay = PayrollSettings()
    @State private var month = Date()
    @AppStorage("shiftly.salaryGoal") private var salaryGoal = 120_000.0
    var body: some View {
        NavigationStack {
            Form {
                let result = payroll(for: store, settings: pay, month: month)
                Section("Расчёт за месяц") {
                    DatePicker("Месяц", selection: $month, displayedComponents: .date)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Уже начислено · оценка")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Text(result.estimated, format: .currency(code: "RUB"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(violet)
                        Label("Прогноз строится по твоим ставкам", systemImage: "sparkles")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .shiftlyGlass(radius: 23, emphasis: true)
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
                Section("Цель на месяц") {
                    let projected = PayrollProjection.calculate(store: store, settings: pay, month: month).total
                    LabeledContent("Прогноз", value: projected.formatted(.currency(code: "RUB")))
                    ProgressView(value: min(1, projected / max(1, salaryGoal))).tint(violet)
                    HStack {
                        Text("Цель, ₽")
                        Spacer()
                        TextField("120000", value: $salaryGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 130)
                    }
                }
                Section("Твои ставки") {
                    HStack { Text("₽ за час"); Spacer(); TextField("0", value: $pay.hourlyRate, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
                    HStack { Text("Коэффициент ночных"); Spacer(); TextField("1.2", value: $pay.nightMultiplier, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70) }
                    HStack { Text("Коэффициент подработки"); Spacer(); TextField("1.5", value: $pay.overtimeMultiplier, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70) }
                    HStack { Text("Премия, ₽"); Spacer(); TextField("0", value: $pay.monthlyBonus, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 110) }
                }
                Section { Text("Предварительная оценка, не расчётный лист. Реальные выплаты зависят от правил предприятия, удержаний и того, какие смены уже учтены в истории.").font(.caption).foregroundStyle(.secondary) }
            }.scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Зарплата")
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
                            }.frame(maxWidth: .infinity).frame(height: 55)
                                .shiftlyGlass(radius: 12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Calendar.current.isDateInToday(day) ? Color.purple : Color.clear, lineWidth: 1.5))
                        }
                    }
                    Text("Д — день 08–20 · Н — ночь 20–08 · В — выходной · розовая полоска — записанный отдых")
                        .font(.caption).foregroundStyle(.secondary)
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
                }.padding(13).shiftlyGlass(radius: 16).listRowBackground(Color.clear)
            }.scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("История").overlay { if store.data.sessions.isEmpty { ContentUnavailableView("История пуста", systemImage: "clock") } }
        }
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
                Section("Резервные копии") {
                    NavigationLink { BackupCenterView() } label: {
                        Label("Открыть центр резервных копий", systemImage: "externaldrive.fill.badge.timemachine")
                    }
                    Text("Просмотр, экспорт и восстановление JSON. Перед восстановлением создаётся страховочная копия.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("О приложении") {
                    Text("Shiftly \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · сборка \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")")
                    Text("Версия IPA: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    Text("Данные хранятся локально на устройстве.").font(.caption).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Настройки")
        }
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
                Image(systemName: "sparkle")
                    .font(.caption).foregroundStyle(palette.accent)
                Text(subtitle)
                    .font(.caption2.bold()).tracking(1)
                    .foregroundStyle(.secondary)
                Text(remaining < 0 ? "+" + timeString(-remaining) : timeString(remaining))
                    .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.62).lineLimit(1)
                    .foregroundStyle(remaining < 0 ? .orange : .white)
                Text("SHIFTLY · OPERATOR")
                    .font(.caption2.bold()).tracking(1.4)
                    .foregroundStyle(palette.accent)
            }
            .padding(18)
        }
        .frame(width: compact ? 160 : 236, height: compact ? 160 : 236)
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
            }.scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Журнал линии")
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

struct BackupControls: View {
    @EnvironmentObject var store: ShiftStore
    @State private var exportingJSON = false
    @State private var exportingCSV = false
    @State private var importing = false
    @State private var showingRestoreConfirmation = false
    @State private var pendingRestore: ShiftData?
    @State private var pendingFileName = ""
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
        Text("Восстановление заменяет текущие данные. Перед заменой Shiftly сохранит страховочную копию на этом устройстве.")
            .font(.caption).foregroundStyle(.secondary)
            .fileExporter(isPresented: $exportingJSON, document: ShiftBackupDocument(data: store.data), contentType: .json, defaultFilename: "Shiftly-backup") { _ in }
            .fileExporter(isPresented: $exportingCSV, document: ShiftCSVDocument(data: store.data), contentType: .commaSeparatedText, defaultFilename: "Shiftly-export") { _ in }
            // Some Files providers label an exported .json as generic data instead
            // of public.json, making it greyed out when filtering only by .json.
            // Allow picking a file, then validate its actual JSON contents.
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                do {
                    let url = try result.get()
                    guard url.isFileURL, !url.hasDirectoryPath else {
                        message = "Выбери файл резервной копии, а не папку"
                        return
                    }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let contents = try Data(contentsOf: url)
                    let restored = try JSONDecoder().decode(ShiftData.self, from: contents)
                    pendingRestore = restored
                    pendingFileName = url.lastPathComponent
                    showingRestoreConfirmation = true
                } catch {
                    message = "Не удалось прочитать резервную копию. Выбери JSON-файл, сохранённый из Shiftly. \(error.localizedDescription)"
                }
            }
            .alert("Восстановить данные Shiftly?", isPresented: $showingRestoreConfirmation) {
                Button("Отмена", role: .cancel) {
                    pendingRestore = nil
                }
                Button("Восстановить", role: .destructive) {
                    guard let restored = pendingRestore else { return }
                    guard AutomaticBackups.saveBeforeRestore(store.data) else {
                        message = "Не получилось сохранить страховочную копию. Восстановление отменено."
                        pendingRestore = nil
                        return
                    }
                    store.replaceData(restored)
                    pendingRestore = nil
                    message = "Данные восстановлены из \(pendingFileName)"
                }
            } message: {
                Text("Текущая история будет заменена данными из файла «\(pendingFileName)». Перед заменой создадим отдельную локальную копию текущей истории.")
            }
    }
}
