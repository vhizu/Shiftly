import Foundation
import UserNotifications
import ActivityKit



@MainActor
final class LiveDiagnostics: ObservableObject {
    static let shared = LiveDiagnostics()
    @Published var status = "Ожидание запуска перерыва"
    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
}

enum BreakAlerts {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    static func start(remainingSeconds: TimeInterval, limitSeconds: TimeInterval,
                      singleBreakSeconds: TimeInterval = 15 * 60, breakStartedAt: Date = Date()) {
        let elapsed = max(0, Date().timeIntervalSince(breakStartedAt))
        let totalRemaining = max(0, remainingSeconds - elapsed)
        let singleRemaining = max(0, singleBreakSeconds - elapsed)
        BreakNoticeScheduler.start(totalRemaining: totalRemaining, singleRemaining: singleRemaining)
        Task { @MainActor in
            // Stop old activities BEFORE starting the new one, avoiding the previous start/stop race.
            for activity in Activity<ShiftlyBreakAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                LiveDiagnostics.shared.status = "Live Activities отключены системой"
                return
            }
            let now = Date()
            let attributes = ShiftlyBreakAttributes(startedAt: min(breakStartedAt, now))
            let state = ShiftlyBreakAttributes.ContentState(
                deadline: now.addingTimeInterval(singleRemaining),
                totalDeadline: now.addingTimeInterval(totalRemaining),
                limitSeconds: limitSeconds,
                usedSeconds: max(0, limitSeconds - totalRemaining))
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
        BreakNoticeScheduler.stop()
        Task { @MainActor in
            for activity in Activity<ShiftlyBreakAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            LiveDiagnostics.shared.status = "Перерыв завершён"
        }
    }
}
