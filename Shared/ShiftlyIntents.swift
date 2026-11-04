import Foundation
import ActivityKit
import AppIntents
import WidgetKit
import UserNotifications

struct ShiftlyBreakAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date             // 15-minute individual break deadline
        var totalDeadline: Date        // Remaining overall rest budget
        var limitSeconds: Double
        var usedSeconds: Double
    }
    var startedAt: Date
}

enum ShiftlyShared {
    static let suite = "group.com.shiftly.app"
    static let dataKey = "shiftly.v1.data"
    static let finishRequestKey = "shiftly.finishBreak.request"
    static let startRequestKey = "shiftly.startBreak.request"
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
        BreakNoticeScheduler.stop()
        WidgetCenter.shared.reloadAllTimelines()
        for activity in Activity<ShiftlyBreakAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

// Interactive Home Screen widget action (iOS 17+).
// Opens Shiftly to activate the full Live Activity and alert scheduler reliably.
struct StartBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Начать перекур"
    static var description = IntentDescription("Начать перекур текущей смены одним нажатием")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let now = Date()
        let defaults = ShiftlyShared.defaults
        guard let raw = defaults.data(forKey: ShiftlyShared.dataKey),
              var snapshot = try? JSONDecoder().decode(ShiftData.self, from: raw),
              let i = snapshot.sessions.lastIndex(where: { $0.start <= now && ($0.end == nil || $0.end! > now) }),
              !snapshot.sessions[i].breaks.contains(where: { $0.end == nil }) else { return .result() }
        snapshot.sessions[i].breaks.append(BreakSession(start: now))
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: ShiftlyShared.dataKey)
            defaults.set(now.timeIntervalSince1970, forKey: ShiftlyShared.startRequestKey)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: Notification.Name("shiftly.widgetStart"), object: nil)
        }
        return .result()
    }
}
