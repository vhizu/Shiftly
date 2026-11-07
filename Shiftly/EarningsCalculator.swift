import Foundation

// A calendar-day ledger. A recorded session takes precedence over its planned
// shift, so the same 12-hour shift is never paid twice in the forecast.
struct EarningsDay: Identifiable {
    var id: Date { date }
    let date: Date
    let amount: Double
    let actual: Double
    let forecast: Double
    let isOvertime: Bool
    let description: String
    let shiftCount: Int
}

struct EarningsMonth {
    let days: [EarningsDay]
    let actual: Double
    let forecast: Double
    let bonus: Double
    var total: Double { actual + forecast + bonus }
    var projectedShifts: Int { days.reduce(0) { $0 + $1.shiftCount } }
}

@MainActor enum EarningsCalculator {
    static func month(store: ShiftStore, settings: PayrollSettings, date: Date) -> EarningsMonth {
        let calendar = Calendar.current
        guard let range = calendar.dateInterval(of: .month, for: date),
              let numberOfDays = calendar.range(of: .day, in: .month, for: range.start)?.count else {
            return EarningsMonth(days: [], actual: 0, forecast: 0, bonus: 0)
        }
        let rate = max(0, settings.hourlyRate)
        let now = Date()
        var rows: [EarningsDay] = []
        for index in 0..<numberOfDays {
            guard let day = calendar.date(byAdding: .day, value: index, to: range.start) else { continue }
            let sessions = store.data.sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }
            let extras = store.data.extras.filter { calendar.isDate($0.start, inSameDayAs: day) }
            let regular = store.regularInterval(on: day)
            var actualValue = 0.0
            var forecastValue = 0.0
            var kinds: [String] = []
            var overtime = false
            for session in sessions {
                let end = max(session.start, session.end ?? now)
                let net = max(0, end.timeIntervalSince(session.start) - store.breakSeconds(session, now: end)) / 3600
                let night = min(net, nightHours(in: DateInterval(start: session.start, end: max(end, session.start.addingTimeInterval(1)))))
                let isExtra = extras.contains { abs($0.start.timeIntervalSince(session.start)) < 3600 }
                actualValue += EarningsMath.amount(rate: rate, hours: net, nightHours: night,
                                                   nightMultiplier: settings.nightMultiplier,
                                                   overtimeMultiplier: settings.overtimeMultiplier,
                                                   overtime: isExtra)
                overtime = overtime || isExtra
                kinds.append(isExtra ? "Подработка · факт" : "Смена · факт")
            }
            var planned: [(interval: DateInterval, extra: Bool)] = []
            if let regular { planned.append((regular, false)) }
            planned += extras.map { (DateInterval(start: $0.start, end: $0.end), true) }
            for plan in planned {
                // Count no planned entry intersecting a real session, including a
                // session with slightly edited start time or a night across midnight.
                let recorded = store.data.sessions.map { session -> DateInterval in
                    let end = max(session.start.addingTimeInterval(1), session.end ?? now)
                    return DateInterval(start: session.start, end: end)
                }
                if !EarningsMath.shouldCountPlan(plan.interval, recorded: recorded) { continue }
                let hours = plan.interval.duration / 3600
                let night = nightHours(in: plan.interval)
                forecastValue += EarningsMath.amount(rate: rate, hours: hours, nightHours: night,
                                                     nightMultiplier: settings.nightMultiplier,
                                                     overtimeMultiplier: settings.overtimeMultiplier,
                                                     overtime: plan.extra)
                overtime = overtime || plan.extra
                kinds.append(plan.extra ? "Подработка · план" : "По графику · план")
            }
            rows.append(EarningsDay(date: day, amount: actualValue + forecastValue,
                                    actual: actualValue, forecast: forecastValue,
                                    isOvertime: overtime,
                                    description: kinds.isEmpty ? "Выходной / без записей" : kinds.joined(separator: " · "),
                                    shiftCount: planned.count + max(0, sessions.count - planned.count)))
        }
        return EarningsMonth(days: rows, actual: rows.reduce(0) { $0 + $1.actual },
                             forecast: rows.reduce(0) { $0 + $1.forecast },
                             bonus: max(0, settings.monthlyBonus))
    }
}
