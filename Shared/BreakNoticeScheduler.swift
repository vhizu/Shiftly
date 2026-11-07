import Foundation
import UserNotifications

enum BreakNoticeScheduler {
    static let prefix = "shiftly.break."
    static let ids = ["single5", "single2", "single1", "single0", "total30", "total15", "total5", "total0", "forgot"]
    static func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids.map { prefix + $0 })
        // Also remove identifiers used by Shiftly 1.4.x.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["30","15","5","0"].map { prefix + $0 })
    }
    static func start(totalRemaining: TimeInterval, singleRemaining: TimeInterval, kind: BreakKind = .smoke) {
        stop()
        let center = UNUserNotificationCenter.current()
        let label = kind.title
        let notices: [(String, TimeInterval, String, String)] = [
            ("single5", singleRemaining - 300, "\(label): осталось 5 минут", "Скоро пора возвращаться к работе"),
            ("single2", singleRemaining - 120, "\(label): осталось 2 минуты", "Закругляйся, оператор 💜"),
            ("single1", singleRemaining - 60, "\(label): осталась 1 минута", "Пора заканчивать"),
            ("single0", singleRemaining, "\(label): время вышло", "Если уже работаешь, заверши таймер"),
            ("total30", totalRemaining - 1800, "Осталось 30 минут отдыха на смену", "Проверь общий лимит"),
            ("total15", totalRemaining - 900, "Осталось 15 минут отдыха на смену", "Общий лимит скоро закончится"),
            ("total5", totalRemaining - 300, "Осталось 5 минут отдыха на смену", "Проверь общий лимит"),
            ("total0", totalRemaining, "Общий лимит отдыха исчерпан", "Останови перерыв, когда вернёшься к работе"),
            ("forgot", max(singleRemaining + 300, kind == .lunch ? 35 * 60 : 20 * 60),
             "Shiftly 💜 · Перерыв ещё идёт?", "Если уже работаешь, заверши перерыв")
        ]
        let prefs = UserDefaults.standard
        func enabled(_ key: String) -> Bool { (prefs.object(forKey: key) as? Bool) ?? true }
        for (id, delay, title, message) in notices where delay > 1 {
            if id.hasPrefix("single") && !enabled("shiftly.remind.break") { continue }
            if id.hasPrefix("total") && !enabled("shiftly.remind.limit") { continue }
            if id == "forgot" && !enabled("shiftly.remind.missed") { continue }
            let notification = UNMutableNotificationContent()
            notification.title = title
            notification.body = message
            notification.sound = .default
            center.add(UNNotificationRequest(identifier: prefix + id, content: notification,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)))
        }
    }
}
