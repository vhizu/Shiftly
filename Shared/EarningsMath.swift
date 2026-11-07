import Foundation

// Pure calculations shared by the calendar and Linux/CI model tests.
enum EarningsMath {
    static func shouldCountPlan(_ planned: DateInterval, recorded: [DateInterval]) -> Bool {
        !recorded.contains { actual in
            actual.intersects(planned) || abs(actual.start.timeIntervalSince(planned.start)) < 3600
        }
    }

    static func amount(rate: Double, hours: Double, nightHours: Double,
                       nightMultiplier: Double, overtimeMultiplier: Double,
                       overtime: Bool) -> Double {
        let paidHours = max(0, hours)
        let nights = min(paidHours, max(0, nightHours))
        return max(0, rate) * (paidHours * (overtime ? max(0, overtimeMultiplier) : 1)
                                + nights * max(0, nightMultiplier - 1))
    }
}
