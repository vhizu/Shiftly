import Foundation
import UserNotifications

// All shift notifications are built using the same schedule as the calendar.
// Only shiftly.shift.* requests are replaced, never active break reminders.
@MainActor enum ShiftReminders {
    static func schedule(store: ShiftStore) {
        let center = UNUserNotificationCenter.current()
        let enabled = store.data.remindEnabled ?? true
        let cal = Calendar.current
        let now = Date()
        var requests: [UNNotificationRequest] = []
        if enabled {
            var intervals: [DateInterval] = []
            for offset in 0..<14 {
                if let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                   let interval = store.regularInterval(on: day) { intervals.append(interval) }
            }
            intervals += store.data.extras.map { DateInterval(start: $0.start, end: $0.end) }
            var seen = Set<Int>()
            for interval in intervals.sorted(by: { $0.start < $1.start }) {
                let key = Int(interval.start.timeIntervalSince1970)
                guard seen.insert(key).inserted else { continue }
                for minutes in [60, 15] {
                    let fire = interval.start.addingTimeInterval(-Double(minutes * 60))
                    guard fire > now else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "Shiftly 💜 · Скоро смена"
                    content.body = minutes == 60 ? "Через час на смену. Проверь график и подготовься." : "До смены 15 минут. Пора собираться!"
                    content.sound = .default
                    let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    requests.append(UNNotificationRequest(
                        identifier: "shiftly.shift.\(key).\(minutes)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
                }
            }
        }
        // Fetch/remove/schedule in one callback. The previous code removed
        // pending IDs asynchronously AFTER adding new requests, causing a race.
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers:
                pending.filter { $0.identifier.hasPrefix("shiftly.shift.") }.map(\.identifier))
            for request in requests { center.add(request) }
        }
    }

    // Re-plan local break notifications without ending/restarting Live Activities.
    static func refreshActiveBreak(store: ShiftStore) {
        guard let session = store.current, let active = store.activeBreak else {
            BreakNoticeScheduler.stop()
            return
        }
        let now = Date()
        let allowed = active.type == .lunch ? 30 : store.perBreakLimitMinutes
        let single = max(0, Double(allowed * 60) - now.timeIntervalSince(active.start))
        let total = max(0, Double(session.breakLimitMinutes * 60) - store.breakSeconds(session, now: now))
        BreakNoticeScheduler.start(totalRemaining: total, singleRemaining: single, kind: active.type)
    }
}
