import Foundation

@main struct ModelCompatibility {
    static func main() throws {
        let old = BreakSession(start: Date(timeIntervalSince1970: 1000),
                               end: Date(timeIntervalSince1970: 1600))
        let oldRaw = try JSONEncoder().encode(old)
        let oldJSON = String(data: oldRaw, encoding: .utf8)!
        precondition(!oldJSON.contains("\"kind\""), "Legacy fixture must omit kind")
        let decodedOld = try JSONDecoder().decode(BreakSession.self, from: oldRaw)
        precondition(decodedOld.type == .smoke, "Old break must decode as smoke")

        let lunch = BreakSession(start: Date(timeIntervalSince1970: 2000),
                                 end: Date(timeIntervalSince1970: 3800), kind: .lunch)
        let roundTrip = try JSONDecoder().decode(BreakSession.self,
                                                 from: JSONEncoder().encode(lunch))
        precondition(roundTrip.type == .lunch, "Lunch type must survive JSON roundtrip")
        precondition(roundTrip.seconds(asOf: Date()) == 1800, "Lunch duration must be 30m")

        let shift = WorkSession(start: Date(timeIntervalSince1970: 900),
                                end: Date(timeIntervalSince1970: 3900),
                                breaks: [decodedOld, roundTrip], breakLimitMinutes: 120)
        let used = shift.breaks.reduce(0.0) { $0 + $1.seconds(asOf: shift.end!) }
        precondition(used == 2400, "Smoking + lunch must consume the shared limit")
        precondition(shift.breakLimitMinutes * 60 - Int(used) == 4800)

        let oldData = ShiftData(sessions: [shift])
        let data = try JSONEncoder().encode(oldData)
        let decodedData = try JSONDecoder().decode(ShiftData.self, from: data)
        precondition(decodedData.sessions.count == 1)
        precondition(decodedData.sessions[0].breaks[0].type == .smoke)
        precondition(decodedData.sessions[0].breaks[1].type == .lunch)
        // The absent optional fields on 1.11.2 files must still decode as the legacy cycle.
        precondition(decodedData.customSchedule == nil)
        precondition(decodedData.scheduleOverrides == nil)
        let calendar = Calendar(identifier: .gregorian)
        var day = DateComponents(year: 2026, month: 11, day: 4)
        day.hour = 12
        let firstNight = calendar.date(from: day)!
        precondition(ShiftScheduleRules.kind(on: firstNight, cycle: nil, overrides: [],
                                             calendar: calendar) == .night,
                     "Nov 4 legacy pattern must be night")
        day.day = 3
        let previous = calendar.date(from: day)!
        precondition(ShiftScheduleRules.kind(on: previous, cycle: nil, overrides: [],
                                             calendar: calendar) == .off)
        day.day = 9
        let nextCycle = calendar.date(from: day)!
        precondition(ShiftScheduleRules.kind(on: nextCycle, cycle: nil, overrides: [],
                                             calendar: calendar) == .day)

        // User-defined arbitrary cycle; should repeat across the anchor, even in the past.
        let custom = ShiftCycle(anchor: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!,
                                days: [.day, .night, .off])
        day.day = 5
        let customDay = calendar.date(from: day)!
        precondition(custom.kind(on: customDay, calendar: calendar) == .night)
        let changed = ShiftDayOverride(date: calendar.startOfDay(for: customDay), kind: .vacation)
        precondition(ShiftScheduleRules.kind(on: customDay, cycle: custom,
                                             overrides: [changed], calendar: calendar) == .vacation)
        precondition(ShiftScheduleRules.interval(on: customDay, cycle: custom,
                                                 overrides: [changed], calendar: calendar) == nil)
        let night = ShiftScheduleRules.interval(on: customDay, cycle: custom,
                                                 overrides: [], calendar: calendar)!
        precondition(calendar.component(.hour, from: night.start) == 20)
        precondition(night.duration == 12 * 3600)
        precondition(ShiftScheduleRules.conflict(with: night, cycle: custom,
                                                overrides: [], calendar: calendar) != nil)
        precondition(ShiftScheduleRules.conflict(with: night, cycle: custom,
                                                overrides: [changed], calendar: calendar) == nil)

        var customizedData = decodedData
        customizedData.customSchedule = custom
        customizedData.scheduleOverrides = [changed]
        customizedData.scheduleRevisedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let customRoundtrip = try JSONDecoder().decode(ShiftData.self, from: JSONEncoder().encode(customizedData))
        precondition(customRoundtrip.customSchedule?.days == [.day, .night, .off])
        precondition(customRoundtrip.scheduleOverrides?.first?.kind == .vacation)
        precondition(customRoundtrip.sessions.count == 1, "Schedule edits must preserve history")
        let expected = DateInterval(start: Date(timeIntervalSince1970: 10_000), duration: 12 * 3600)
        let actual = DateInterval(start: expected.start.addingTimeInterval(12 * 60),
                                  duration: 12 * 3600)
        precondition(!EarningsMath.shouldCountPlan(expected, recorded: [actual]),
                     "Recorded shifts must replace scheduled shifts")
        precondition(EarningsMath.shouldCountPlan(expected, recorded: []))
        let actualPay = EarningsMath.amount(rate: 250, hours: 11.5, nightHours: 7.5,
                                            nightMultiplier: 1.2, overtimeMultiplier: 1.5,
                                            overtime: false)
        precondition(abs(actualPay - 3250) < 0.001, "Night premium must be separate")
        let extraPay = EarningsMath.amount(rate: 250, hours: 12, nightHours: 0,
                                           nightMultiplier: 1.2, overtimeMultiplier: 1.5,
                                           overtime: true)
        precondition(abs(extraPay - 4500) < 0.001, "Overtime multiplier calculation")
        // A full twelve-hour shift is paid for eleven hours, regardless of
        // the smoking/lunch events logged for safety and break monitoring.
        let fullDay = EarningsMath.shift(rate: 544.09, duration: 12 * 3600,
                                        rawNightHours: 0, paidPerShift: 11,
                                        paidNightPerShift: 7, nightMultiplier: 1.4,
                                        overtimeMultiplier: 1.5, hazardPercent: 4,
                                        overtime: false)
        precondition(abs(fullDay.paidHours - 11) < 0.00001)
        precondition(fullDay.paidNightHours == 0)
        let fullNight = EarningsMath.shift(rate: 544.09, duration: 12 * 3600,
                                          rawNightHours: 8, paidPerShift: 11,
                                          paidNightPerShift: 7, nightMultiplier: 1.4,
                                          overtimeMultiplier: 1.5, hazardPercent: 4,
                                          overtime: false)
        precondition(abs(fullNight.paidNightHours - 7) < 0.00001)
        precondition(abs(fullNight.nightPremium - 1_523.452) < 0.0001)

        // October 2026 pay slip, reconstructed exclusively from displayed
        // payroll items; monthly user history is NOT prefilled with this sample.
        let octoberBase = EarningsMath.currency(154 * 544.09)
        let octoberNight = EarningsMath.currency(49 * 544.09 * 0.4)
        let octoberHazard = EarningsMath.currency(octoberBase * 0.04)
        let septemberPremiumPaidInOctober = EarningsMath.currency(octoberBase * 0.16)
        let octoberGross = octoberBase + octoberNight + octoberHazard + septemberPremiumPaidInOctober + 6070.90
        precondition(abs(octoberBase - 83_789.86) < 0.01)
        precondition(abs(octoberNight - 10_664.16) < 0.01)
        precondition(abs(octoberGross - 117_282.89) < 0.001, "Gross slip must match to cents")
        let octoberTax = EarningsMath.approximateTax(gross: octoberGross,
                                                    taxableBenefits: 6890, taxPercent: 13)
        precondition(octoberTax == 16_142, "Rounded NDFL with food benefit")
        precondition(abs(EarningsMath.remaining(gross: octoberGross, tax: octoberTax,
                                               advance: 41_702.69) - 59_438.20) < 0.001,
                     "Slip remainder must match")

        let samplePay = PayrollBackup(hourlyRate: 544.09, nightMultiplier: 1.4,
                                      overtimeMultiplier: 1.5, legacyMonthlyBonus: 0,
                                      paidHoursPerShift: 11, paidNightHoursPerShift: 7,
                                      hazardPercent: 4, estimatedPremiumPercent: 16,
                                      taxPercent: 13,
                                      adjustments: ["2026-10": PayrollMonthAdjustments(
                                        premiumPercent: 16, actualPremium: 13406.38,
                                        actualAdvance: 41702.69, downtimeGross: 6070.90,
                                        otherGross: 0, taxableMeals: 6890, actualTax: 16142)])
        var withPay = decodedData
        withPay.payrollBackup = samplePay
        let paidRoundtrip = try JSONDecoder().decode(ShiftData.self, from: JSONEncoder().encode(withPay))
        precondition(paidRoundtrip.payrollBackup == samplePay,
                     "JSON backup must preserve monthly pay history")
        precondition(decodedData.payrollBackup == nil,
                     "Legacy data remains readable without pay history")
        print("PASS: legacy JSON, lunch, schedule, overlap, salary, payslip, backup and deduplication rules")
    }
}
