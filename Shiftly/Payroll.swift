import Foundation
import SwiftUI

@MainActor final class PayrollSettings: ObservableObject {
    @Published var hourlyRate: Double { didSet { save() } }
    @Published var nightMultiplier: Double { didSet { save() } }
    @Published var overtimeMultiplier: Double { didSet { save() } }
    @Published var monthlyBonus: Double { didSet { save() } }
    init() {
        let d = UserDefaults.standard
        hourlyRate = d.object(forKey: "shiftly.pay.hourly") as? Double ?? 0
        nightMultiplier = d.object(forKey: "shiftly.pay.night") as? Double ?? 1.2
        overtimeMultiplier = d.object(forKey: "shiftly.pay.overtime") as? Double ?? 1.5
        monthlyBonus = d.object(forKey: "shiftly.pay.bonus") as? Double ?? 0
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(hourlyRate, forKey: "shiftly.pay.hourly")
        d.set(nightMultiplier, forKey: "shiftly.pay.night")
        d.set(overtimeMultiplier, forKey: "shiftly.pay.overtime")
        d.set(monthlyBonus, forKey: "shiftly.pay.bonus")
    }
}

struct PaySummary {
    var normalHours: Double = 0
    var nightHours: Double = 0
    var overtimeHours: Double = 0
    var estimated: Double = 0
}

func nightHours(in interval: DateInterval) -> Double {
    // Hour-level segments are sufficient for 08:00 / 20:00 scheduled shifts.
    var t = interval.start
    var total = 0.0
    while t < interval.end {
        let next = min(interval.end, t.addingTimeInterval(900))
        let h = Calendar.current.component(.hour, from: t)
        if h >= 22 || h < 6 { total += next.timeIntervalSince(t) / 3600 }
        t = next
    }
    return total
}

func payroll(for store: ShiftStore, settings: PayrollSettings, month: Date) -> PaySummary {
    let cal = Calendar.current
    guard let range = cal.dateInterval(of: .month, for: month) else { return PaySummary() }
    var result = PaySummary()
    for s in store.data.sessions {
        let end = s.end ?? Date()
        guard end > s.start, let intersection = DateInterval(start: s.start, end: end).intersection(with: range) else { continue }
        let gross = intersection.duration / 3600
        let overlapBreaks = s.breaks.compactMap { b -> Double? in
            guard let i = DateInterval(start: b.start, end: max(b.start.addingTimeInterval(1), b.end ?? Date())).intersection(with: intersection) else { return nil }
            return i.duration / 3600
        }.reduce(0, +)
        let net = max(0, gross - overlapBreaks)
        let night = min(net, nightHours(in: intersection))
        result.normalHours += net
        result.nightHours += night
    }
    // Extra shifts count separately only when not already recorded as a work session.
    for e in store.data.extras {
        guard let intersection = DateInterval(start: e.start, end: e.end).intersection(with: range) else { continue }
        if store.data.sessions.contains(where: { DateInterval(start: $0.start, end: $0.end ?? Date()).intersects(intersection) }) { continue }
        result.overtimeHours += intersection.duration / 3600
    }
    result.estimated = max(0, settings.hourlyRate) * (result.normalHours + result.nightHours * max(0, settings.nightMultiplier - 1) + result.overtimeHours * max(0, settings.overtimeMultiplier)) + settings.monthlyBonus
    return result
}
