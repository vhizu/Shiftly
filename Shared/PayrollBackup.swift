import Foundation

struct PayrollMonthAdjustments: Codable, Equatable {
    var premiumPercent: Double? = nil            // Month-specific estimate; otherwise use global estimate.
    var actualPremium: Double? = nil             // Nil = estimate, some = the actual payout.
    var actualAdvance: Double? = nil             // Nil = 1–15 forecast.
    var downtimeGross: Double = 0
    var otherGross: Double = 0
    var taxableMeals: Double = 0                 // NDFL base only, not cash earnings.
    var actualTax: Double? = nil                 // Use when cumulative NDFL differs from the estimate.
}


// All payroll overrides are optional for legacy ShiftData JSON files.
// Encoded inside ShiftData, so exporting/importing a backup also keeps pay history.
struct PayrollBackup: Codable, Equatable {
    var hourlyRate: Double
    var nightMultiplier: Double
    var overtimeMultiplier: Double
    var legacyMonthlyBonus: Double
    var paidHoursPerShift: Double
    var paidNightHoursPerShift: Double
    var hazardPercent: Double
    var estimatedPremiumPercent: Double
    var taxPercent: Double
    var adjustments: [String: PayrollMonthAdjustments]
}
