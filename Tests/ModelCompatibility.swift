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
        print("PASS: legacy JSON, lunch, schedule, overlap, salary and deduplication rules")
    }
}
