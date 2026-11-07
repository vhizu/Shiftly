import Foundation

// A single schedule model shared by the calendar, automatic shift tracking,
// shift reminders and salary forecasts. Absent values retain the old 8-day cycle.
enum ShiftDayKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case day, night, off, vacation, sick

    var id: String { rawValue }
    var shortLabel: String {
        switch self {
        case .day: return "Д"
        case .night: return "Н"
        case .off: return "В"
        case .vacation: return "О"
        case .sick: return "Б"
        }
    }
    var title: String {
        switch self {
        case .day: return "Дневная 08–20"
        case .night: return "Ночная 20–08"
        case .off: return "Выходной"
        case .vacation: return "Отпуск"
        case .sick: return "Больничный"
        }
    }
    var startHour: Int? {
        switch self {
        case .day: return 8
        case .night: return 20
        default: return nil
        }
    }
    var isWorking: Bool { startHour != nil }
}

struct ShiftCycle: Codable {
    var anchor: Date
    var days: [ShiftDayKind]

    static var original: ShiftCycle {
        let calendar = Calendar.current
        return ShiftCycle(
            anchor: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!,
            days: [.day, .day, .off, .night, .night, .off, .off, .off]
        )
    }

    func index(on date: Date, calendar: Calendar = .current) -> Int {
        let count = max(1, days.count)
        let delta = calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor),
                                            to: calendar.startOfDay(for: date)).day ?? 0
        return ((delta % count) + count) % count
    }

    func kind(on date: Date, calendar: Calendar = .current) -> ShiftDayKind {
        guard !days.isEmpty else { return .off }
        return days[index(on: date, calendar: calendar)]
    }
}

struct ShiftDayOverride: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var kind: ShiftDayKind
}

// Dates are calendar days. A night shift belongs to its 20:00 starting day.
enum ShiftScheduleRules {
    static func kind(on date: Date, cycle: ShiftCycle?, overrides: [ShiftDayOverride],
                     calendar: Calendar = .current) -> ShiftDayKind {
        if let oneOff = overrides.last(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return oneOff.kind
        }
        return (cycle ?? .original).kind(on: date, calendar: calendar)
    }

    static func interval(on date: Date, cycle: ShiftCycle?, overrides: [ShiftDayOverride],
                         calendar: Calendar = .current) -> DateInterval? {
        let type = kind(on: date, cycle: cycle, overrides: overrides, calendar: calendar)
        guard let hour = type.startHour,
              let start = calendar.date(bySettingHour: hour, minute: 0, second: 0,
                                        of: calendar.startOfDay(for: date)) else { return nil }
        return DateInterval(start: start, duration: 12 * 3600)
    }

    // Verify all nearby starting dates because a 20:00 shift runs into tomorrow.
    static func conflict(with proposed: DateInterval, cycle: ShiftCycle?,
                         overrides: [ShiftDayOverride], calendar: Calendar = .current) -> DateInterval? {
        let day = calendar.startOfDay(for: proposed.start)
        for offset in -1...1 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let interval = interval(on: date, cycle: cycle, overrides: overrides,
                                          calendar: calendar) else { continue }
            if proposed.intersects(interval) { return interval }
        }
        return nil
    }
}
