import Foundation
import UserNotifications
import ActivityKit

struct ShiftlyBreakAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var limitSeconds: Double
        var usedSeconds: Double
    }
    var startedAt: Date
}

@MainActor
final class LiveDiagnostics: ObservableObject {
    static let shared = LiveDiagnostics()
    @Published var status = "Ожидание запуска перерыва"
    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
}

enum BreakAlerts {
    static let prefix = "shiftly.break."
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    static func start(remainingSeconds: TimeInterval, limitSeconds: TimeInterval) {
        let seconds = max(0, remainingSeconds)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [prefix + "15", prefix + "5", prefix + "0"])
        for (minutes, title, message) in [
            (15, "Shiftly: осталось 15 минут", "Лимит перерывов скоро закончится"),
            (5, "Shiftly: осталось 5 минут", "Пора заканчивать перекур"),
            (0, "Shiftly: лимит исчерпан", "Время перерывов на эту смену закончилось")
        ] {
            let delay = seconds - Double(minutes * 60)
            guard delay > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            center.add(UNNotificationRequest(identifier: prefix + String(minutes), content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)))
        }
        Task { @MainActor in
            // Stop old activities BEFORE starting the new one, avoiding the previous start/stop race.
            for activity in Activity<ShiftlyBreakAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                LiveDiagnostics.shared.status = "Live Activities отключены системой"
                return
            }
            let attributes = ShiftlyBreakAttributes(startedAt: Date())
            let state = ShiftlyBreakAttributes.ContentState(deadline: Date().addingTimeInterval(seconds), limitSeconds: limitSeconds, usedSeconds: max(0, limitSeconds - seconds))
            do {
                let activity = try Activity<ShiftlyBreakAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil)
                LiveDiagnostics.shared.status = "Запущена: " + activity.id
            } catch {
                LiveDiagnostics.shared.status = "Ошибка: " + error.localizedDescription
            }
        }
    }
    static func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prefix + "15", prefix + "5", prefix + "0"])
        Task { @MainActor in
            for activity in Activity<ShiftlyBreakAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            LiveDiagnostics.shared.status = "Перерыв завершён"
        }
    }
}
