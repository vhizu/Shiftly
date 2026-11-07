import Foundation
import SwiftUI

// Adjustments are attached to the month in which the payroll slip is paid.
// A September performance bonus paid in October lives in October's entry.
@MainActor final class PayrollSettings: ObservableObject {
    @Published var hourlyRate: Double { didSet { save() } }
    @Published var nightMultiplier: Double { didSet { save() } }
    @Published var overtimeMultiplier: Double { didSet { save() } }
    @Published var monthlyBonus: Double { didSet { save() } } // Legacy global monthly addition.
    @Published var paidHoursPerShift: Double { didSet { save() } }
    @Published var paidNightHoursPerShift: Double { didSet { save() } }
    @Published var hazardPercent: Double { didSet { save() } }
    @Published var estimatedPremiumPercent: Double { didSet { save() } }
    @Published var taxPercent: Double { didSet { save() } }
    @Published var adjustments: [String: PayrollMonthAdjustments] { didSet { save() } }
    private weak var linkedStore: ShiftStore?
    private var importingSnapshot = false

    init() {
        let d = UserDefaults.standard
        let savedRate = d.object(forKey: "shiftly.pay.hourly") as? Double
        hourlyRate = (savedRate ?? 0) > 0 ? savedRate! : 544.09
        let savedNight = d.object(forKey: "shiftly.pay.night") as? Double
        // The old app defaulted to 1.20. Upgrade that *default* to the 1.40
        // confirmed by the user's October payslip; preserve custom coefficients.
        nightMultiplier = (savedNight == nil || abs(savedNight! - 1.2) < 0.00001) ? 1.4 : savedNight!
        overtimeMultiplier = d.object(forKey: "shiftly.pay.overtime") as? Double ?? 1.5
        monthlyBonus = d.object(forKey: "shiftly.pay.bonus") as? Double ?? 0
        paidHoursPerShift = d.object(forKey: "shiftly.pay.paidHours") as? Double ?? 11
        paidNightHoursPerShift = d.object(forKey: "shiftly.pay.paidNightHours") as? Double ?? 7
        hazardPercent = d.object(forKey: "shiftly.pay.hazard") as? Double ?? 4
        estimatedPremiumPercent = d.object(forKey: "shiftly.pay.premiumEstimate") as? Double ?? 16
        taxPercent = d.object(forKey: "shiftly.pay.taxRate") as? Double ?? 13
        if let raw = d.data(forKey: "shiftly.pay.monthAdjustments"),
           let decoded = try? JSONDecoder().decode([String: PayrollMonthAdjustments].self, from: raw) {
            adjustments = decoded
        } else { adjustments = [:] }
    }

    static func key(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    func month(_ date: Date) -> PayrollMonthAdjustments {
        adjustments[Self.key(for: date)] ?? PayrollMonthAdjustments()
    }

    func editMonth(_ date: Date, _ edit: (inout PayrollMonthAdjustments) -> Void) {
        let key = Self.key(for: date)
        var value = adjustments[key] ?? PayrollMonthAdjustments()
        edit(&value)
        adjustments[key] = value
    }

    var snapshot: PayrollBackup {
        PayrollBackup(hourlyRate: hourlyRate, nightMultiplier: nightMultiplier,
                      overtimeMultiplier: overtimeMultiplier, legacyMonthlyBonus: monthlyBonus,
                      paidHoursPerShift: paidHoursPerShift,
                      paidNightHoursPerShift: paidNightHoursPerShift,
                      hazardPercent: hazardPercent,
                      estimatedPremiumPercent: estimatedPremiumPercent,
                      taxPercent: taxPercent, adjustments: adjustments)
    }

    // Wire monthly pay inputs into the same JSON backup as the shifts.
    func attach(store: ShiftStore) {
        linkedStore = store
        if let restored = store.data.payrollBackup {
            importingSnapshot = true
            hourlyRate = restored.hourlyRate
            nightMultiplier = restored.nightMultiplier
            overtimeMultiplier = restored.overtimeMultiplier
            monthlyBonus = restored.legacyMonthlyBonus
            paidHoursPerShift = restored.paidHoursPerShift
            paidNightHoursPerShift = restored.paidNightHoursPerShift
            hazardPercent = restored.hazardPercent
            estimatedPremiumPercent = restored.estimatedPremiumPercent
            taxPercent = restored.taxPercent
            adjustments = restored.adjustments
            importingSnapshot = false
            save()
        } else {
            store.setPayrollBackup(snapshot)
        }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(hourlyRate, forKey: "shiftly.pay.hourly")
        d.set(nightMultiplier, forKey: "shiftly.pay.night")
        d.set(overtimeMultiplier, forKey: "shiftly.pay.overtime")
        d.set(monthlyBonus, forKey: "shiftly.pay.bonus")
        d.set(paidHoursPerShift, forKey: "shiftly.pay.paidHours")
        d.set(paidNightHoursPerShift, forKey: "shiftly.pay.paidNightHours")
        d.set(hazardPercent, forKey: "shiftly.pay.hazard")
        d.set(estimatedPremiumPercent, forKey: "shiftly.pay.premiumEstimate")
        d.set(taxPercent, forKey: "shiftly.pay.taxRate")
        if let raw = try? JSONEncoder().encode(adjustments) {
            d.set(raw, forKey: "shiftly.pay.monthAdjustments")
        }
        if !importingSnapshot { linkedStore?.setPayrollBackup(snapshot) }
    }
}

// Preserve this shared helper (used by both actual and planned shift calculations).
func nightHours(in interval: DateInterval) -> Double {
    var time = interval.start
    var result = 0.0
    while time < interval.end {
        let next = min(interval.end, time.addingTimeInterval(900))
        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 22 || hour < 6 { result += next.timeIntervalSince(time) / 3600 }
        time = next
    }
    return result
}

struct PaycheckBreakdown {
    let base: Double
    let night: Double
    let extra: Double
    let hazard: Double
    let premium: Double
    let premiumEstimated: Bool
    let premiumBasis: Double
    let downtime: Double
    let other: Double
    let taxableMeals: Double
    let calculatedTax: Double
    let tax: Double
    let actualTax: Bool
    let advanceForecast: Double
    let advance: Double
    let actualAdvance: Bool
    let paidHours: Double
    let nightHours: Double
    var gross: Double { base + night + extra + hazard + premium + downtime + other }
    var afterTax: Double { gross - tax }
    var toPay: Double { EarningsMath.remaining(gross: gross, tax: tax, advance: advance) }
}

@MainActor enum PayrollCalculator {
    static func statement(store: ShiftStore, settings: PayrollSettings, month: Date) -> PaycheckBreakdown {
        let ledger = EarningsCalculator.month(store: store, settings: settings, date: month)
        let prior = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
        let previous = EarningsCalculator.month(store: store, settings: settings, date: prior)
        let item = settings.month(month)
        let percent = item.premiumPercent ?? settings.estimatedPremiumPercent
        // The prior month's base is the *forecast* premium basis only. The real
        // employer formula is not confirmed. User can enter the actual premium.
        let predictedPremium = EarningsMath.currency(previous.basic * max(0, percent) / 100)
        let premium = EarningsMath.currency(max(0, item.actualPremium ?? predictedPremium))
        let base = EarningsMath.currency(ledger.basic)
        let night = EarningsMath.currency(ledger.nightPremium)
        let extra = EarningsMath.currency(ledger.overtimePremium)
        let hazard = EarningsMath.currency(ledger.hazard)
        let downtime = EarningsMath.currency(max(0, item.downtimeGross))
        let other = EarningsMath.currency(item.otherGross + settings.monthlyBonus)
        let meals = EarningsMath.currency(max(0, item.taxableMeals))
        let gross = base + night + extra + hazard + premium + downtime + other
        let estimatedTax = EarningsMath.approximateTax(gross: gross, taxableBenefits: meals,
                                                       taxPercent: settings.taxPercent)
        // Estimate using base earnings of shifts starting 1st–15th. Payroll might
        // include additional items and cumulative tax; actual override is supported.
        let advanceBase = ledger.days.filter { Calendar.current.component(.day, from: $0.date) <= 15 }
            .reduce(0) { $0 + $1.basic }
        let advanceEstimate = EarningsMath.currency(max(0, advanceBase * (1 - min(100, max(0, settings.taxPercent)) / 100)))
        return PaycheckBreakdown(base: base, night: night, extra: extra, hazard: hazard,
                                 premium: premium, premiumEstimated: item.actualPremium == nil,
                                 premiumBasis: previous.basic, downtime: downtime, other: other,
                                 taxableMeals: meals, calculatedTax: estimatedTax,
                                 tax: EarningsMath.currency(max(0, item.actualTax ?? estimatedTax)), actualTax: item.actualTax != nil,
                                 advanceForecast: advanceEstimate,
                                 advance: EarningsMath.currency(max(0, item.actualAdvance ?? advanceEstimate)),
                                 actualAdvance: item.actualAdvance != nil,
                                 paidHours: ledger.paidHours, nightHours: ledger.paidNightHours)
    }
}
