import Foundation
import ActivityKit
import AppIntents

struct ShiftlyBreakAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var limitSeconds: Double
        var usedSeconds: Double
    }
    var startedAt: Date
}

enum ShiftlyShared {
    static let suite = "group.com.shiftly.app"
    static let dataKey = "shiftly.v1.data"
    static let finishRequestKey = "shiftly.finishBreak.request"
    static var defaults: UserDefaults { UserDefaults(suiteName: suite) ?? .standard }
}

struct FinishBreakIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Вернулся к работе"
    static var description = IntentDescription("Завершить текущий перерыв Shiftly")
    func perform() async throws -> some IntentResult {
        let now = Date()
        // Shared storage lets the intent finish a break without launching the UI.
        let defaults = ShiftlyShared.defaults
        if let raw = defaults.data(forKey: ShiftlyShared.dataKey),
           var snapshot = try? JSONDecoder().decode(ShiftData.self, from: raw),
           let i = snapshot.sessions.lastIndex(where: { $0.start <= now && ($0.end == nil || $0.end! > now) }),
           let j = snapshot.sessions[i].breaks.lastIndex(where: { $0.end == nil }) {
            snapshot.sessions[i].breaks[j].end = now
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: ShiftlyShared.dataKey)
            }
        }
        defaults.set(now.timeIntervalSince1970, forKey: ShiftlyShared.finishRequestKey)
        for activity in Activity<ShiftlyBreakAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
