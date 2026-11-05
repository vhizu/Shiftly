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
                        ShiftlyMenuRow(symbol: "clock.arrow.circlepath", title: "История", subtitle: "Перекуры, обеды и отчёты", accent: accent)
                    }
                    NavigationLink { LineJournalView() } label: {
                        ShiftlyMenuRow(symbol: "wrench.adjustable.fill", title: "Журнал линии", subtitle: "Заметки оператора", accent: .orange)
                    }
                    ShiftlySectionHeader(title: "Отдых")
                        .padding(.top, 8)
                    NavigationLink { BreakHubView() } label: {
                        ShiftlyMenuRow(symbol: "cup.and.saucer.fill", title: "Центр перерывов", subtitle: "Обед, перекуры и исправления", accent: .pink)
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

// Mascot fades into the *full* screen backdrop. No fixed-height dark panels.
struct HomeMascotBackdrop: View {
    let onBreak: Bool
    let remainingSingle: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("shiftly.motion") private var motionEnabled = true
    @State private var floating = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var imageName: String {
        onBreak && remainingSingle > 120 ? "MascotBreak" : "MascotWork"
    }
    private var shouldAnimate: Bool { motionEnabled && !reduceMotion && !lowPower }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 1.28, 560)
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .offset(x: width * 0.15, y: shouldAnimate && floating ? -6 : 4)
                    .mask {
                        LinearGradient(stops: [
                            .init(color: .white, location: 0.00),
                            .init(color: .white, location: 0.55),
                            .init(color: .white.opacity(0.75), location: 0.70),
                            .init(color: .clear, location: 0.96)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                // This is full-height and seamless, unlike the old 78% rectangle.
                LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.22), location: 0),
                    .init(color: Color.black.opacity(0.05), location: 0.34),
                    .init(color: Color.clear, location: 0.65),
                    .init(color: Color.black.opacity(0.20), location: 1)
                ], startPoint: .leading, endPoint: .trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { updateMotion() }
        .onChange(of: motionEnabled) { _, _ in updateMotion() }
        .onChange(of: reduceMotion) { _, _ in updateMotion() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            updateMotion()
        }
    }

    private func updateMotion() {
        if shouldAnimate {
            withAnimation(.easeInOut(duration: 3.3).repeatForever(autoreverses: true)) { floating = true }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { floating = false }
        }
    }
}

struct HomeMascotMood: View {
    let mood: MascotMood
    let now: Date
    @AppStorage("shiftly.talkFrequency") private var talkFrequency = "normal"
    @State private var taps = 0

    private var phrase: String {
        let interval: Double = talkFrequency == "rare" ? 900 : talkFrequency == "often" ? 120 : 300
        let bucket = Int(now.timeIntervalSince1970 / interval)
        // Time-driven phrases are stable between buckets and don't flicker every second.
        let chosen: MascotMood = (Calendar.current.component(.hour, from: now) == 3 && bucket % 17 == 0) ? .rare : mood
        return MascotLines.phrase(for: chosen, index: bucket + taps)
    }

    var body: some View {
        Button {
            taps += 1
            ShiftlyFeedback.light()
        } label: {
            Label(phrase, systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.20), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Операторша. " + phrase)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ShiftStore
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    @State private var showQuickPastBreak = false
    @State private var showFocus = false
    @State private var confirmEnd = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var recentSession: WorkSession? {
        store.current ?? store.data.sessions.max(by: { $0.start < $1.start })
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: lowPower ? 5 : 1)) { tick in
                let now = tick.date
                let session = store.current
                let active = store.activeBreak
                let activeLimit = active?.type == .lunch ? 30 : store.perBreakLimitMinutes
                let singleRemaining = active.map { Double(activeLimit * 60) - now.timeIntervalSince($0.start) }
                    ?? Double(activeLimit * 60)
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session == nil ? "ВЫХОДНОЙ" : active?.type == .lunch ? "ВРЕМЯ ОБЕДА" : active == nil ? "ТВОЯ СМЕНА" : "ВРЕМЯ ОТДЫХА")
                                .font(.caption2.bold()).tracking(1.6).foregroundStyle(palette.accent)
                            Text(session == nil ? "Отдыхай 💜" : active?.type == .lunch ? "Приятного аппетита" : active == nil ? "Всё под контролем" : "Перекур")
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let session {
                            let untilEnd = max(0, (session.end ?? session.start.addingTimeInterval(12 * 3600)).timeIntervalSince(now))
                            let remaining = Double(session.breakLimitMinutes * 60) - store.breakSeconds(session, now: now)
                            Color.clear.frame(height: 96)
                                .overlay(alignment: .bottomLeading) {
                                    HomeMascotMood(mood: mood(session: session, active: active, singleRemaining: singleRemaining, remaining: remaining, untilEnd: untilEnd, now: now), now: now)
                                }
                            activeCard(session: session, now: now, active: active,
                                       singleRemaining: singleRemaining, totalRemaining: remaining, untilEnd: untilEnd)
                            actionButtons(active: active)
                        } else {
                            idleContent(now: now)
                        }

                        if let action = store.undoAction, now < action.expiresAt {
                            HStack(spacing: 9) {
                                Label(action.label, systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold()).foregroundStyle(.white)
                                Spacer(minLength: 2)
                                Button("Отменить") {
                                    if store.undoLastBreakAction() { ShiftlyFeedback.success() }
                                }
                                .font(.caption.bold())
                                .buttonStyle(.bordered)
                                .tint(palette.accent)
                            }
                            .padding(11)
                            .shiftlyGlass(radius: 16)
                        }
                        if let error = store.persistenceWarning {
                            Label(error, systemImage: "externaldrive.badge.exclamationmark")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .background {
                    ZStack {
                        ShiftlyBackdrop()
                        if session != nil {
                            HomeMascotBackdrop(onBreak: active != nil, remainingSingle: singleRemaining)
                        }
                    }
                }
            }
            .navigationTitle("Shiftly")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                store.synchronize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .sheet(isPresented: $showFocus) { ShiftlyFocusView() }
            .sheet(isPresented: $showQuickPastBreak) {
                if let session = recentSession { QuickPastBreakEditor(sessionID: session.id) }
                else { NavigationStack { BreakHubView() } }
            }
            .confirmationDialog("Завершить смену?", isPresented: $confirmEnd) {
                Button("Завершить смену", role: .destructive) { store.endWork(); ShiftlyFeedback.success() }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Это закроет текущую смену и остановит активный перерыв.")
            }
        }
    }

    private func mood(session: WorkSession, active: BreakSession?, singleRemaining: TimeInterval,
                      remaining: TimeInterval, untilEnd: TimeInterval, now: Date) -> MascotMood {
        if remaining <= 300 { return .warning }
        if let active {
            if active.type == .lunch { return singleRemaining <= 300 ? .lunchLate : .lunch }
            return singleRemaining <= 180 ? .smokeLate : .smoke
        }
        if untilEnd <= 3600 { return .finalHour }
        if untilEnd <= 6 * 3600 { return .halfway }
        return Calendar.current.component(.hour, from: session.start) >= 14 ? .night : .day
    }

    private func activeCard(session: WorkSession, now: Date, active: BreakSession?,
                            singleRemaining: TimeInterval, totalRemaining: TimeInterval,
                            untilEnd: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(active?.type == .lunch ? "Обед идёт" : active == nil ? "Смена идёт" : "Перекур активен",
                      systemImage: active?.type == .lunch ? "fork.knife" : active == nil ? "briefcase.fill" : "cup.and.saucer.fill")
                    .font(.subheadline.bold()).foregroundStyle(palette.accent)
                Spacer(minLength: 4)
                Text("С " + ruDate(session.start))
                    .font(.caption2).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            HStack(spacing: 10) {
                ShiftRing(remaining: active == nil ? untilEnd : singleRemaining,
                          total: active == nil ? 12 * 3600 : Double((active!.type == .lunch ? 30 : store.perBreakLimitMinutes) * 60),
                          subtitle: active == nil ? "ДО КОНЦА СМЕНЫ" : active!.type == .lunch ? "ОБЕД · 30 МИН" : "ПЕРЕКУР",
                          compact: true)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    Text("ОСТАТОК ОТДЫХА")
                        .font(.caption2.bold()).tracking(0.6).foregroundStyle(.white.opacity(0.72))
                    Text(timeString(max(0, totalRemaining)))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                    ProgressView(value: min(1, max(0, totalRemaining / Double(max(1, session.breakLimitMinutes * 60)))))
                        .tint(totalRemaining < 300 ? .orange : palette.accent)
                    Text("Обед и перекуры входят в один лимит")
                        .font(.caption2).foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                ShiftlyStatChip(symbol: "briefcase.fill", title: "Работа", value: timeString(store.workSeconds(session, now: now)))
                ShiftlyStatChip(symbol: "cup.and.saucer.fill", title: "Отдых", value: timeString(store.breakSeconds(session, now: now)))
            }
            if totalRemaining < 0 {
                Label("Лимит превышен на " + timeString(-totalRemaining), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(.orange)
            } else if active == nil {
                Text(RestForecast.message(remaining: totalRemaining, minutesPerBreak: store.perBreakLimitMinutes,
                                          untilShiftEnd: untilEnd, active: false))
                    .font(.caption).foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(16)
        .shiftlyGlass(radius: 24, emphasis: true)
    }

    private func actionButtons(active: BreakSession?) -> some View {
        VStack(spacing: 10) {
            if let active {
                Button {
                    store.finishBreak()
                    ShiftlyFeedback.success()
                } label: {
                    Label(active.type == .lunch ? "Завершить обед" : "Вернулся к работе",
                          systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(ShiftlyPrimaryButtonStyle())
            } else {
                Button {
                    store.startBreak(kind: .smoke)
                    ShiftlyFeedback.medium()
                } label: {
                    Label("Начать перекур · 15 мин", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(ShiftlyPrimaryButtonStyle())
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                if active == nil {
                    Button {
                        store.startBreak(kind: .lunch)
                        ShiftlyFeedback.medium()
                    } label: { Label("Обед · 30 мин", systemImage: "fork.knife")
                        .frame(maxWidth: .infinity).frame(height: 58).shiftlyGlassControl(radius: 18) }
                }
                Button { showQuickPastBreak = true; ShiftlyFeedback.light() } label: {
                    Label("Забытый перерыв", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity).frame(height: 58).shiftlyGlassControl(radius: 18)
                }
                Button { showFocus = true; ShiftlyFeedback.light() } label: {
                    Label("Фокус", systemImage: "scope")
                        .frame(maxWidth: .infinity).frame(height: 58).shiftlyGlassControl(radius: 18)
                }
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            Button { confirmEnd = true; ShiftlyFeedback.warning() } label: {
                Label("Завершить смену", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.80))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .shiftlyGlassControl(radius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    private func idleContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if let next = store.nextScheduledShift(after: now) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Следующая смена", systemImage: "calendar.badge.clock")
                        .font(.headline).foregroundStyle(palette.accent)
                    Text(ruDate(next.interval.start))
                        .font(.title3.bold()).foregroundStyle(.white)
                    let seconds = max(0, next.interval.start.timeIntervalSince(now))
                    Text("Через \(Int(seconds / 86400)) д \(Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)) ч · \(next.extra ? "Подработка" : "По графику")")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.73))
                }
                .padding(17).shiftlyGlass(radius: 22)
            }
            if let last = store.data.sessions.filter({ $0.end != nil && $0.end! <= now })
                .max(by: { $0.end! < $1.end! }),
               let ended = last.end, now.timeIntervalSince(ended) < 48 * 3600 {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Смена завершена", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(palette.accent)
                    HStack(spacing: 11) {
                        ShiftlyStatChip(symbol: "briefcase.fill", title: "Работал", value: timeString(store.workSeconds(last)))
                        ShiftlyStatChip(symbol: "cup.and.saucer.fill", title: "Отдых", value: timeString(store.breakSeconds(last)))
                    }
                    HStack {
                        Label("Перекуров: \(last.breaks.filter { $0.type == .smoke }.count)", systemImage: "cup.and.saucer")
                        Spacer()
                        Label("Обедов: \(last.breaks.filter { $0.type == .lunch }.count)", systemImage: "fork.knife")
                    }
                    .font(.caption).foregroundStyle(.white.opacity(0.82))
                    NavigationLink {
                        ShiftReportView(sessionID: last.id)
                    } label: {
                        Label("Подробный отчёт", systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline.bold())
                    }
                }
                .padding(16).shiftlyGlass(radius: 22)
            } else {
                Text("Сегодня нет активной смены. Можно отдыхать 💜")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.76))
                    .padding(17).shiftlyGlass(radius: 22)
            }
            HomeMascotMood(mood: .idle, now: now)
            Button("Начать внеплановую смену") { store.startWork(); ShiftlyFeedback.medium() }
                .buttonStyle(ShiftlyPrimaryButtonStyle())
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
                let smokes = allBreaks.filter { $0.type == .smoke }
                let lunches = allBreaks.filter { $0.type == .lunch }
                let smokeSeconds = smokes.reduce(0.0) { $0 + $1.seconds(asOf: Date()) }
                let average = smokes.isEmpty ? 0 : Int(smokeSeconds / Double(smokes.count) / 60)
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
                        stat("Перекуров", "\(smokes.count)", "cup.and.saucer.fill")
                        stat("Обедов", "\(lunches.count)", "fork.knife")
                    }
                    ShiftlySectionHeader(title: "Перерывы за неделю")
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
    @AppStorage("shiftly.haptics") private var haptics = true
    @AppStorage("shiftly.autoAtmosphere") private var autoAtmosphere = true
    @AppStorage("shiftly.talkFrequency") private var talkFrequency = "normal"
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
                Section("Обед") {
                    Label("Обед — 30 минут", systemImage: "fork.knife")
                    Text("Обед учитывается внутри общего лимита 120/150 минут вместе с перекурами. В истории обеды отмечены отдельно.")
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
                    Toggle("Автоматическая атмосфера дня и ночи", isOn: $autoAtmosphere)
                    Text("При энергосбережении и системном уменьшении движения анимации приостанавливаются.")
                        .font(.caption).foregroundStyle(.secondary)
                    if #available(iOS 26.0, *) {
                        Text("Настоящий Liquid Glass доступен на этом iPhone")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("На этой версии iOS используется полупрозрачный стиль с системным материалом")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Операторша 💜") {
                    Picker("Частота реплик", selection: $talkFrequency) {
                        Text("Редко").tag("rare")
                        Text("Обычно").tag("normal")
                        Text("Часто").tag("often")
                    }
                    Toggle("Тактильная отдача", isOn: $haptics)
                    Text("144 офлайн-реплики. Нажми на подпись операторши, чтобы услышать другую. Без лишних push-уведомлений.")
                        .font(.caption).foregroundStyle(.secondary)
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
                Text(subtitle == "ДО КОНЦА СМЕНЫ" ? "ДО КОНЦА" : subtitle)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .tracking(compact ? 0.2 : 0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(Color.white.opacity(0.78))
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
                Section("Перерывы") {
                    Button { addingPastBreak = true } label: {
                        Label("Добавить забытый перерыв", systemImage: "plus.circle.fill")
                    }
                    ForEach(session.breaks) { item in
                        NavigationLink {
                            BreakEditor(sessionID: sessionID, item: item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.type.title + " · " + item.start.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "ru_RU"))))
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
    @State private var kind: BreakKind = .smoke
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Забытый перерыв") {
                    Picker("Тип", selection: $kind) {
                        Text("Перекур · 15 мин").tag(BreakKind.smoke)
                        Text("Обед · 30 мин").tag(BreakKind.lunch)
                    }
                    DatePicker("Начало", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Конец", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    Text("Перекур добавится в историю смены и будет учтён в лимите. Таймер и уведомление не запускаются.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Добавить перерыв") {
                        if let error = store.addPastBreak(sessionID: sessionID, start: start, end: end, kind: kind) {
                            errorMessage = error
                        } else { dismiss() }
                    }
                    .disabled(end <= start || end > Date())
                }
            }
            .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Добавить перерыв")
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
    @State private var kind: BreakKind = .smoke
    var body: some View {
        Form {
            Picker("Тип перерыва", selection: $kind) {
                Text("Перекур").tag(BreakKind.smoke)
                Text("Обед").tag(BreakKind.lunch)
            }
            DatePicker("Начало", selection: $start)
            DatePicker("Конец", selection: $end)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
            Button("Сохранить") {
                if let error = store.editBreak(sessionID: sessionID, breakID: item.id, start: start, end: end, kind: kind) {
                    errorMessage = error
                } else { dismiss() }
            }.disabled(end <= start || end > Date())
            Button("Удалить перерыв", role: .destructive) { confirmDelete = true }
                .confirmationDialog("Удалить эту запись?", isPresented: $confirmDelete) {
                    Button("Удалить", role: .destructive) {
                        store.removeBreak(sessionID: sessionID, breakID: item.id)
                        dismiss()
                    }
                }
        }
        .scrollContentBackground(.hidden).background(ShiftlyBackdrop()).navigationTitle("Исправить перерыв")
        .onAppear { if !ready { start = item.start; end = item.end ?? Date(); kind = item.type; ready = true } }
    }
}

