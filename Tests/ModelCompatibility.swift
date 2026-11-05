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
        print("PASS: old JSON, lunch JSON, shared rest allowance, ShiftData roundtrip")
    }
}
