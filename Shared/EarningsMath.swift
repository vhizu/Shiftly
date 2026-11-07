import Foundation

// Pure, auditable payroll rules. A twelve-hour factory shift pays eleven hours;
// the single unpaid hour is not the sum of all in-app rest timers.
struct ShiftPayParts {
    var paidHours: Double
    var paidNightHours: Double
    var basic: Double
    var nightPremium: Double
    var overtimePremium: Double
    var hazard: Double
    var total: Double { basic + nightPremium + overtimePremium + hazard }
}

enum EarningsMath {
    static func shouldCountPlan(_ planned: DateInterval, recorded: [DateInterval]) -> Bool {
        !recorded.contains { actual in
            actual.intersects(planned) || abs(actual.start.timeIntervalSince(planned.start)) < 3600
        }
    }

    // Retained for backward compatibility with older model calculations.
    static func amount(rate: Double, hours: Double, nightHours: Double,
                       nightMultiplier: Double, overtimeMultiplier: Double,
                       overtime: Bool) -> Double {
        let paidHours = max(0, hours)
        let nights = min(paidHours, max(0, nightHours))
        return max(0, rate) * (paidHours * (overtime ? max(0, overtimeMultiplier) : 1)
                                + nights * max(0, nightMultiplier - 1))
    }

    // Recorded duration is a clock-time span; paid time is a separate payroll metric.
    static func paidHours(duration: TimeInterval, paidPerShift: Double) -> Double {
        min(12, max(0, duration / 3600)) * min(12, max(0, paidPerShift)) / 12
    }

    // The October slip's 49 night hours are consistent with 7 paid night hours
    // per complete 20:00–08:00 shift. Raw 22:00–06:00 covers eight clock hours.
    static func nightPaidHours(rawNightHours: Double, paidHours: Double, paidNightPerShift: Double) -> Double {
        min(max(0, paidHours), max(0, rawNightHours) * min(8, max(0, paidNightPerShift)) / 8)
    }

    static func shift(rate: Double, duration: TimeInterval, rawNightHours: Double,
                      paidPerShift: Double, paidNightPerShift: Double,
                      nightMultiplier: Double, overtimeMultiplier: Double,
                      hazardPercent: Double, overtime: Bool) -> ShiftPayParts {
        let rate = max(0, rate)
        let paid = paidHours(duration: duration, paidPerShift: paidPerShift)
        let night = nightPaidHours(rawNightHours: rawNightHours, paidHours: paid,
                                   paidNightPerShift: paidNightPerShift)
        let basic = paid * rate
        let nightAddition = night * rate * max(0, nightMultiplier - 1)
        let extraAddition = overtime ? basic * max(0, overtimeMultiplier - 1) : 0
        let hazard = basic * max(0, hazardPercent) / 100
        return ShiftPayParts(paidHours: paid, paidNightHours: night, basic: basic,
                             nightPremium: nightAddition, overtimePremium: extraAddition, hazard: hazard)
    }

    static func currency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }

    static func approximateTax(gross: Double, taxableBenefits: Double, taxPercent: Double) -> Double {
        // Payslips show withholding in whole rubles. Actual NDFL can be progressive
        // or corrected cumulatively by payroll, so it is an estimate unless overridden.
        (max(0, gross + max(0, taxableBenefits)) * max(0, taxPercent) / 100).rounded()
    }

    static func remaining(gross: Double, tax: Double, advance: Double) -> Double {
        gross - max(0, tax) - max(0, advance)
    }
}
