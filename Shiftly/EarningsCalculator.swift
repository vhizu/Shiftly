import Foundation

// Ledger by shift start date: a 20:00–08:00 night belongs to the date it starts.
// Stored work sessions supersede their planned copies (including overtime).
struct EarningsDay: Identifiable {
    var id: Date { date }
    let date: Date
    let amount: Double
    let actual: Double
    let forecast: Double
    let basic: Double
    let nightPremium: Double
    let overtimePremium: Double
    let hazard: Double
    let paidHours: Double
    let paidNightHours: Double
    let isOvertime: Bool
    let description: String
    let shiftCount: Int
}

struct EarningsMonth {
    let days: [EarningsDay]
    let actual: Double
    let forecast: Double
    let basic: Double
    let nightPremium: Double
    let overtimePremium: Double
    let hazard: Double
    let paidHours: Double
    let paidNightHours: Double
    var total: Double { actual + forecast }
    var projectedShifts: Int { days.reduce(0) { $0 + $1.shiftCount } }
}

@MainActor enum EarningsCalculator {
    static func month(store: ShiftStore, settings: PayrollSettings, date: Date) -> EarningsMonth {
        let calendar = Calendar.current
        guard let range = calendar.dateInterval(of: .month, for: date),
              let numberOfDays = calendar.range(of: .day, in: .month, for: range.start)?.count else {
            return EarningsMonth(days: [], actual: 0, forecast: 0, basic: 0, nightPremium: 0,
                                 overtimePremium: 0, hazard: 0, paidHours: 0, paidNightHours: 0)
        }
        let now = Date()
        // Precompute all recorded intervals once rather than scanning them per day and plan.
        let recorded: [DateInterval] = store.data.sessions.map { session in
            let end = max(session.start.addingTimeInterval(1), session.end ?? now)
            return DateInterval(start: session.start, end: end)
        }
        var result: [EarningsDay] = []
        for index in 0..<numberOfDays {
            guard let day = calendar.date(byAdding: .day, value: index, to: range.start) else { continue }
            let sessions = store.data.sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }
            let extras = store.data.extras.filter { calendar.isDate($0.start, inSameDayAs: day) }
            var fact = 0.0
            var planAmount = 0.0
            var basic = 0.0
            var nightAddition = 0.0
            var extraAddition = 0.0
            var hazard = 0.0
            var paidHours = 0.0
            var paidNights = 0.0
            var labels: [String] = []
            var overtime = false
            var countedPlans = 0

            func include(_ parts: ShiftPayParts) {
                basic += parts.basic
                nightAddition += parts.nightPremium
                extraAddition += parts.overtimePremium
                hazard += parts.hazard
                paidHours += parts.paidHours
                paidNights += parts.paidNightHours
            }

            for session in sessions {
                let end = max(session.start, session.end ?? now)
                let extra = extras.contains { abs($0.start.timeIntervalSince(session.start)) < 3600 }
                let length = max(0, end.timeIntervalSince(session.start))
                // Do not subtract the sum of rest timers a second time: each 12h
                // factory shift already contains the 1h unpaid break allocation.
                let rawNight = length > 0 ? nightHours(in: DateInterval(start: session.start, end: end)) : 0
                let parts = EarningsMath.shift(rate: settings.hourlyRate, duration: length,
                                               rawNightHours: rawNight,
                                               paidPerShift: settings.paidHoursPerShift,
                                               paidNightPerShift: settings.paidNightHoursPerShift,
                                               nightMultiplier: settings.nightMultiplier,
                                               overtimeMultiplier: settings.overtimeMultiplier,
                                               hazardPercent: settings.hazardPercent, overtime: extra)
                fact += parts.total
                include(parts)
                overtime = overtime || extra
                labels.append(extra ? "Подработка · факт" : "Смена · факт")
            }

            var planned: [(DateInterval, Bool)] = []
            if let ordinary = store.regularInterval(on: day) { planned.append((ordinary, false)) }
            planned += extras.map { (DateInterval(start: $0.start, end: $0.end), true) }
            for (interval, extra) in planned {
                guard EarningsMath.shouldCountPlan(interval, recorded: recorded) else { continue }
                let parts = EarningsMath.shift(rate: settings.hourlyRate, duration: interval.duration,
                                               rawNightHours: nightHours(in: interval),
                                               paidPerShift: settings.paidHoursPerShift,
                                               paidNightPerShift: settings.paidNightHoursPerShift,
                                               nightMultiplier: settings.nightMultiplier,
                                               overtimeMultiplier: settings.overtimeMultiplier,
                                               hazardPercent: settings.hazardPercent, overtime: extra)
                planAmount += parts.total
                include(parts)
                overtime = overtime || extra
                labels.append(extra ? "Подработка · план" : "По графику · план")
                countedPlans += 1
            }
            result.append(EarningsDay(date: day, amount: fact + planAmount, actual: fact,
                                      forecast: planAmount, basic: basic, nightPremium: nightAddition,
                                      overtimePremium: extraAddition, hazard: hazard,
                                      paidHours: paidHours, paidNightHours: paidNights,
                                      isOvertime: overtime,
                                      description: labels.isEmpty ? "Выходной / без записей" : labels.joined(separator: " · "),
                                      shiftCount: sessions.count + countedPlans))
        }
        return EarningsMonth(days: result, actual: result.reduce(0) { $0 + $1.actual },
                             forecast: result.reduce(0) { $0 + $1.forecast },
                             basic: result.reduce(0) { $0 + $1.basic },
                             nightPremium: result.reduce(0) { $0 + $1.nightPremium },
                             overtimePremium: result.reduce(0) { $0 + $1.overtimePremium },
                             hazard: result.reduce(0) { $0 + $1.hazard },
                             paidHours: result.reduce(0) { $0 + $1.paidHours },
                             paidNightHours: result.reduce(0) { $0 + $1.paidNightHours })
    }
}
