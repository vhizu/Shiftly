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
    static func start(totalRemaining: TimeInterval, singleRemaining: TimeInterval) {
        stop()
        let center = UNUserNotificationCenter.current()
        let notices: [(String, TimeInterval, String, String)] = [
            ("single5", singleRemaining - 300, "Перекур: осталось 5 минут", "Скоро пора возвращаться к работе"),
            ("single2", singleRemaining - 120, "Перекур: осталось 2 минуты", "Закругляйся, оператор 💜"),
            ("single1", singleRemaining - 60, "Перекур: осталась 1 минута", "Пора заканчивать"),
            ("single0", singleRemaining, "Лимит одного перекура закончился", "Если уже работаешь, заверши таймер"),
            ("total30", totalRemaining - 1800, "Осталось 30 минут отдыха на смену", "Проверь общий лимит"),
            ("total15", totalRemaining - 900, "Осталось 15 минут отдыха на смену", "Общий лимит скоро закончится"),
            ("total5", totalRemaining - 300, "Осталось 5 минут отдыха на смену", "Проверь общий лимит"),
            ("total0", totalRemaining, "Общий лимит отдыха исчерпан", "Останови перекур, когда вернёшься к работе"),
            ("forgot", 45 * 60, "Shiftly ☕ · Ты ещё на перекуре?", "Если уже работаешь, заверши перерыв")
        ]
        for (id, delay, title, message) in notices where delay > 1 {
            let notification = UNMutableNotificationContent()
            notification.title = title
            notification.body = message
            notification.sound = .default
            center.add(UNNotificationRequest(identifier: prefix + id, content: notification,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)))
        }
    }
}
