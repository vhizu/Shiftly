import SwiftUI

// Shiftly 1.8 visual system. Appearance preferences live in UserDefaults,
// never in ShiftData, so old backup files remain compatible.
enum ShiftlyPalette: String, CaseIterable, Identifiable {
    case violet = "Night Violet"
    case deepBlue = "Deep Blue"
    case factory = "Factory Purple"
    case graphite = "Soft Graphite"
    case neon = "Neon Shift"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .violet: return "Ночная фиалка"
        case .deepBlue: return "Глубокий синий"
        case .factory: return "Заводской пурпур"
        case .graphite: return "Мягкий графит"
        case .neon: return "Неоновая смена"
        }
    }
    var accent: Color {
        switch self {
        case .violet: return Color(red: 0.75, green: 0.49, blue: 1.0)
        case .deepBlue: return Color(red: 0.39, green: 0.70, blue: 1.0)
        case .factory: return Color(red: 0.94, green: 0.45, blue: 0.82)
        case .graphite: return Color(red: 0.73, green: 0.83, blue: 0.98)
        case .neon: return Color(red: 0.56, green: 0.46, blue: 1.0)
        }
    }
    var secondary: Color {
        switch self {
        case .violet: return Color(red: 0.28, green: 0.62, blue: 1.0)
        case .deepBlue: return Color(red: 0.51, green: 0.37, blue: 0.99)
        case .factory: return Color(red: 0.43, green: 0.36, blue: 0.95)
        case .graphite: return Color(red: 0.40, green: 0.60, blue: 0.73)
        case .neon: return Color(red: 0.06, green: 0.87, blue: 0.92)
        }
    }
    var background: [Color] {
        switch self {
        case .violet: return [Color(red: 0.11, green: 0.06, blue: 0.27), Color(red: 0.035, green: 0.035, blue: 0.10), Color(red: 0.035, green: 0.02, blue: 0.08)]
        case .deepBlue: return [Color(red: 0.035, green: 0.10, blue: 0.23), Color(red: 0.035, green: 0.05, blue: 0.12), Color(red: 0.02, green: 0.04, blue: 0.09)]
        case .factory: return [Color(red: 0.17, green: 0.045, blue: 0.17), Color(red: 0.07, green: 0.035, blue: 0.13), Color(red: 0.035, green: 0.025, blue: 0.065)]
        case .graphite: return [Color(red: 0.11, green: 0.14, blue: 0.18), Color(red: 0.055, green: 0.07, blue: 0.11), Color(red: 0.04, green: 0.05, blue: 0.08)]
        case .neon: return [Color(red: 0.12, green: 0.025, blue: 0.25), Color(red: 0.025, green: 0.06, blue: 0.15), Color(red: 0.035, green: 0.02, blue: 0.09)]
        }
    }
}

struct ShiftlyBackdrop: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    @AppStorage("shiftly.neonNight") private var neonNight = true
    @AppStorage("shiftly.motion") private var motionEnabled = true
    @State private var glowMoves = false

    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var isNight: Bool {
        guard let session = store.current else { return false }
        return Calendar.current.component(.hour, from: session.start) >= 14
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(palette.accent.opacity(isNight && neonNight ? 0.34 : 0.17))
                    .frame(width: geometry.size.width * 1.0, height: geometry.size.width * 1.0)
                    .blur(radius: 95)
                    .offset(x: geometry.size.width * (glowMoves ? 0.30 : 0.48),
                            y: geometry.size.height * (glowMoves ? -0.29 : -0.42))
                Circle()
                    .fill(palette.secondary.opacity(isNight && neonNight ? 0.27 : 0.14))
                    .frame(width: geometry.size.width * 0.78, height: geometry.size.width * 0.78)
                    .blur(radius: 95)
                    .offset(x: -geometry.size.width * (glowMoves ? 0.40 : 0.24),
                            y: geometry.size.height * (glowMoves ? 0.20 : 0.34))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .black.opacity(0.20)], startPoint: .top, endPoint: .bottom))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard motionEnabled && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { glowMoves = true }
        }
    }
}

struct ShiftlyGlass: ViewModifier {
    var radius: CGFloat = 22
    var emphasis: Bool = false
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var accent: Color { (ShiftlyPalette(rawValue: themeName) ?? .violet).accent }

    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.07), accent.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9))
                .shadow(color: accent.opacity(emphasis ? 0.22 : 0.09), radius: emphasis ? 25 : 14, y: 9)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.04), accent.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9))
                .shadow(color: accent.opacity(emphasis ? 0.22 : 0.09), radius: emphasis ? 25 : 14, y: 9)
        }
        #else
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.9))
            .shadow(color: accent.opacity(0.10), radius: 14, y: 9)
        #endif
    }
}

extension View {
    func shiftlyGlass(radius: CGFloat = 22, emphasis: Bool = false) -> some View {
        modifier(ShiftlyGlass(radius: radius, emphasis: emphasis))
    }
}

struct ShiftlyPrimaryButtonStyle: ButtonStyle {
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    func makeBody(configuration: Configuration) -> some View {
        let palette = ShiftlyPalette(rawValue: themeName) ?? .violet
        return configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LinearGradient(colors: [palette.accent, palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.34), lineWidth: 1))
            .shadow(color: palette.accent.opacity(0.30), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ShiftlyQuickTile: View {
    let symbol: String
    let title: String
    let detail: String
    var accent: Color = .purple
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 0)
            Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .padding(14)
        .shiftlyGlass(radius: 22)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ShiftlyStatChip: View {
    let symbol: String
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .shiftlyGlass(radius: 18)
    }
}

struct ShiftlyFocusView: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                let session = store.current
                let activeBreak = session?.breaks.last(where: { $0.end == nil })
                let remaining = activeBreak.map { Double(store.perBreakLimitMinutes * 60) - tick.date.timeIntervalSince($0.start) }
                    ?? session.map { Double($0.breakLimitMinutes * 60) - store.breakSeconds($0, now: tick.date) }
                    ?? 0
                VStack(spacing: 27) {
                    Spacer()
                    Image(systemName: activeBreak == nil ? "moon.stars.fill" : "cup.and.saucer.fill")
                        .font(.system(size: 38)).foregroundStyle(.purple)
                    Text(activeBreak == nil ? "Остаток отдыха" : "Текущий перекур")
                        .font(.headline).foregroundStyle(.secondary)
                    ShiftRing(remaining: remaining,
                              total: Double((activeBreak == nil ? (session?.breakLimitMinutes ?? 120) : store.perBreakLimitMinutes) * 60),
                              subtitle: activeBreak == nil ? "ЛИМИТ СМЕНЫ" : "ОДИН ПЕРЕКУР")
                    if session != nil {
                        Button(store.isOnBreak ? "Вернулся к работе" : "Начать перекур") { store.toggleBreak() }
                            .buttonStyle(ShiftlyPrimaryButtonStyle())
                    } else {
                        Text("Сейчас нет активной смены").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ShiftlyBackdrop())
            .navigationTitle("Режим фокуса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}

struct ShiftlyWeekBars: View {
    let sessions: [WorkSession]
    @AppStorage("shiftly.theme") private var themeName = ShiftlyPalette.violet.rawValue
    private var palette: ShiftlyPalette { ShiftlyPalette(rawValue: themeName) ?? .violet }
    private var dates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 6, to: today) }
    }
    private func minutes(on day: Date) -> Double {
        sessions.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .flatMap(\.breaks)
            .reduce(0) { $0 + $1.seconds(asOf: Date()) / 60 }
    }
    var body: some View {
        let values = dates.map(minutes)
        let maximum = max(15, values.max() ?? 15)
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Неделя отдыха", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text("минуты").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(dates.indices, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text("\(Int(values[index]))")
                            .font(.caption2.bold()).foregroundStyle(.secondary)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(LinearGradient(colors: [palette.accent, palette.secondary], startPoint: .top, endPoint: .bottom))
                            .frame(height: max(7, CGFloat(values[index] / maximum) * 92))
                        Text(dates[index].formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "ru_RU"))))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 132, alignment: .bottom)
        }
        .padding(18)
        .shiftlyGlass(radius: 23)
    }
}
