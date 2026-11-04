import Foundation
import UserNotifications

@MainActor enum ShiftReminders {
    static func schedule(store: ShiftStore) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("shiftly.shift.") }.map(\.identifier))
        }
        guard store.data.remindEnabled ?? true else { return }
        let cal = Calendar.current
        let now = Date()
        var intervals: [DateInterval] = []
        for offset in 0..<14 {
            if let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)), let interval = store.regularInterval(on: day) { intervals.append(interval) }
        }
        intervals += store.data.extras.map { DateInterval(start: $0.start, end: $0.end) }
        for interval in intervals {
            for minutes in [60, 15] {
                let fire = interval.start.addingTimeInterval(-Double(minutes * 60))
                guard fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Shiftly 💜 · Скоро смена"
                content.body = minutes == 60 ? "Через час на смену. Готовься, оператор!" : "Через 15 минут начинаем. Допивай кофе!"
                content.sound = .default
                let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let id = "shiftly.shift.\(Int(interval.start.timeIntervalSince1970)).\(minutes)"
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            }
        }
    }
}
