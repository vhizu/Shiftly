import Foundation
import UserNotifications
import ActivityKit

struct WorkSession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    var breaks: [BreakSession] = []
    var breakLimitMinutes: Int
}
struct BreakSession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    func seconds(asOf now: Date) -> TimeInterval { max(0, (end ?? now).timeIntervalSince(start)) }
}
struct ExtraShift: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var isNight: Bool
    var end: Date { start.addingTimeInterval(12 * 3600) }
}
struct ShiftData: Codable {
    var limitMinutes = 120
    var sessions: [WorkSession] = []
    var extras: [ExtraShift] = []
}
@MainActor final class ShiftStore: ObservableObject {
    @Published private(set) var data = ShiftData()
    private let key = "shiftly.v1.data"
    init() {
        if let raw = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode(ShiftData.self, from: raw) { data = decoded }
    }
    var current: WorkSession? { data.sessions.last(where: { $0.end == nil }) }
    var isOnBreak: Bool { current?.breaks.last?.end == nil && current?.breaks.last != nil }
    func breakSeconds(_ session: WorkSession, now: Date = Date()) -> TimeInterval { session.breaks.reduce(0) { $0 + $1.seconds(asOf: now) } }
    func workSeconds(_ session: WorkSession, now: Date = Date()) -> TimeInterval { max(0, (session.end ?? now).timeIntervalSince(session.start) - breakSeconds(session, now: now)) }
    func startWork() { guard current == nil else { return }; data.sessions.append(WorkSession(start: Date(), breakLimitMinutes: data.limitMinutes)); save(); BreakAlerts.requestPermission() }
    func endWork() { guard let i = data.sessions.lastIndex(where: { $0.end == nil }) else { return }; let now = Date(); if let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) { data.sessions[i].breaks[j].end = now }; data.sessions[i].end = now; save(); BreakAlerts.stop() }
    func toggleBreak() { guard let i = data.sessions.lastIndex(where: { $0.end == nil }) else { return }; if let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) { data.sessions[i].breaks[j].end = Date(); BreakAlerts.stop() } else { let now = Date(); let remaining = max(0, Double(data.sessions[i].breakLimitMinutes * 60) - breakSeconds(data.sessions[i], now: now)); data.sessions[i].breaks.append(BreakSession(start: now)); BreakAlerts.start(remainingSeconds: remaining, limitSeconds: Double(data.sessions[i].breakLimitMinutes * 60)) }; save() }
    func setLimit(_ minutes: Int) { data.limitMinutes = max(1, minutes); save() }
    func addExtra(_ date: Date, night: Bool) -> Bool {
        let cal = Calendar.current
        let start = cal.date(bySettingHour: night ? 20 : 8, minute: 0, second: 0, of: date) ?? date
        let proposed = DateInterval(start: start, duration: 12 * 3600)
        if data.extras.contains(where: { proposed.intersects(DateInterval(start: $0.start, end: $0.end)) }) { return false }
        // Regular shifts: compare intervals from nearby days, including nights spanning midnight.
        for offset in -1...1 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: date)), let interval = regularInterval(on: day) else { continue }
            if proposed.intersects(interval) { return false }
        }
        data.extras.append(ExtraShift(start: start, isNight: night)); data.extras.sort { $0.start < $1.start }; save(); return true
    }
    func removeExtra(_ id: UUID) { data.extras.removeAll { $0.id == id }; save() }
    // Nov 4, 2026 = cycle day 4 (first night). Cycle: D D O N N O O O.
    func cycleIndex(on date: Date) -> Int {
        let cal = Calendar.current
        let anchor = cal.date(from: DateComponents(year: 2026, month: 11, day: 4))!
        let delta = cal.dateComponents([.day], from: anchor, to: cal.startOfDay(for: date)).day ?? 0
        return ((delta + 3) % 8 + 8) % 8
    }
    func regularInterval(on day: Date) -> DateInterval? {
        let index = cycleIndex(on: day)
        let hour: Int
        if index == 0 || index == 1 { hour = 8 }
        else if index == 3 || index == 4 { hour = 20 }
        else { return nil }
        guard let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return nil }
        return DateInterval(start: start, duration: 12 * 3600)
    }
    func dayLabel(_ date: Date) -> String {
        switch cycleIndex(on: date) { case 0,1: return "Д"; case 3,4: return "Н"; default: return "В" }
    }
    private func save() { if let raw = try? JSONEncoder().encode(data) { UserDefaults.standard.set(raw, forKey: key) }; objectWillChange.send() }
}
