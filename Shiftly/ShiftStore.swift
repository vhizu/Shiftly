import Foundation
import UserNotifications
import ActivityKit
import WidgetKit

struct ShiftlyUndoAction: Identifiable {
    enum Operation { case started, finished }
    let id = UUID()
    let sessionID: UUID
    let breakID: UUID
    let operation: Operation
    let kind: BreakKind
    let issuedAt: Date
    let label: String
    var expiresAt: Date { issuedAt.addingTimeInterval(20) }
}

@MainActor final class ShiftStore: ObservableObject {
    @Published private(set) var data = ShiftData()
    @Published private(set) var undoAction: ShiftlyUndoAction?
    @Published private(set) var persistenceWarning: String?
    private let key = ShiftlyShared.dataKey
    init() {
        if let raw = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode(ShiftData.self, from: raw) { data = decoded }
        if let shared = ShiftlyShared.defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(ShiftData.self, from: shared) {
            if decoded.sessions.count >= data.sessions.count { data = decoded }
        }
        let localReadable = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(ShiftData.self, from: $0) } != nil
        let sharedReadable = ShiftlyShared.defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ShiftData.self, from: $0) } != nil
        if !localReadable && !sharedReadable,
           let previous = AutomaticBackups.loadLatest() { data = previous }
        // Recreate the scheduled shift from its real start time after reinstall.
        // No need to press "Start shift" at the time the app is first opened.
        synchronize(now: Date())
        if !AutomaticBackups.save(data) {
            persistenceWarning = "Не получилось обновить локальную резервную копию"
        }
        ShiftReminders.schedule(store: self)
    }
    var current: WorkSession? {
        let now = Date()
        return data.sessions.last(where: { $0.start <= now && ($0.end == nil || $0.end! > now) })
    }
    var notes: [LineNote] { data.notes ?? [] }
    var autoEnabled: Bool { data.autoEnabled ?? true }
    var perBreakLimitMinutes: Int { max(1, data.perBreakLimitMinutes ?? 15) }
    func setPerBreakLimit(_ minutes: Int) { data.perBreakLimitMinutes = max(1, minutes); save() }
    func setAuto(_ enabled: Bool) { data.autoEnabled = enabled; save(); synchronize() }
    func setReminders(_ enabled: Bool) { data.remindEnabled = enabled; save(); ShiftReminders.schedule(store: self) }
    func addNote(_ note: LineNote) { if data.notes == nil { data.notes = [] }; data.notes!.append(note); save() }
    func removeNote(_ id: UUID) { data.notes?.removeAll { $0.id == id }; save() }
    func synchronize(now: Date = Date()) {
        applyExternalBreakStart()
        applyExternalBreakEnd()
        guard autoEnabled else { return }
        let cal = Calendar.current
        // Synchronize a bounded window, including overnight shifts and extra shifts.
        for offset in -14...1 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            if let interval = regularInterval(on: day) { ensureSession(start: interval.start, end: interval.end, now: now) }
        }
        for extra in data.extras { ensureSession(start: extra.start, end: extra.end, now: now) }

        // Explicitly reconcile the shift containing *now*, including a night
        // shift that began yesterday. This is important on a fresh install
        // opened after the shift began (e.g. 23:30 for a 20:00 night shift).
        for offset in -1...0 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let interval = regularInterval(on: day),
                  interval.start <= now, now < interval.end else { continue }
            ensureSession(start: interval.start, end: interval.end, now: now)
        }
        for extra in data.extras where extra.start <= now && now < extra.end {
            ensureSession(start: extra.start, end: extra.end, now: now)
        }
    }
    private func applyExternalBreakStart() {
        let defaults = ShiftlyShared.defaults
        let stamp = defaults.double(forKey: ShiftlyShared.startRequestKey)
        guard stamp > 0 else { return }
        defaults.removeObject(forKey: ShiftlyShared.startRequestKey)
        let startedAt = Date(timeIntervalSince1970: stamp)
        // Merge the widget transaction even if the break was immediately finished
        // from the lock screen before the main app became active.
        guard let raw = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ShiftData.self, from: raw),
              let session = snapshot.sessions.last(where: { s in
                  s.breaks.contains(where: { abs($0.start.timeIntervalSince(startedAt)) < 3 })
              }) else { return }
        data = snapshot
        save()
        guard session.breaks.contains(where: { abs($0.start.timeIntervalSince(startedAt)) < 3 && $0.end == nil }) else { return }
        let remaining = max(0, Double(session.breakLimitMinutes * 60) - breakSeconds(session, now: startedAt))
        BreakAlerts.start(remainingSeconds: remaining,
                          limitSeconds: Double(session.breakLimitMinutes * 60),
                          singleBreakSeconds: Double(((session.breaks.last(where: { abs($0.start.timeIntervalSince(startedAt)) < 3 })?.type == .lunch) ? 30 : perBreakLimitMinutes) * 60),
                          breakStartedAt: startedAt,
                          kind: session.breaks.last(where: { abs($0.start.timeIntervalSince(startedAt)) < 3 })?.type ?? .smoke)
    }
    private func applyExternalBreakEnd() {
        let defaults = ShiftlyShared.defaults
        let stamp = defaults.double(forKey: ShiftlyShared.finishRequestKey)
        guard stamp > 0 else { return }
        defaults.removeObject(forKey: ShiftlyShared.finishRequestKey)
        let finishedAt = Date(timeIntervalSince1970: stamp)
        if let i = data.sessions.lastIndex(where: { $0.start <= finishedAt && ($0.end == nil || $0.end! > finishedAt) }),
           let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) {
            data.sessions[i].breaks[j].end = finishedAt
            save()
            BreakAlerts.stop()
        }
    }
    private func ensureSession(start: Date, end: Date, now: Date) {
        guard start <= now else { return }
        if let i = data.sessions.firstIndex(where: { abs($0.start.timeIntervalSince(start)) < 60 }) {
            if data.sessions[i].isAutomatic == true {
                let expectedEnd: Date? = now >= end ? end : nil
                var changed = data.sessions[i].end != expectedEnd
                if now >= end, let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) {
                    // A night shift can finish while the app is closed.
                    data.sessions[i].breaks[j].end = end
                    changed = true
                }
                if changed {
                    data.sessions[i].end = expectedEnd
                    save()
                }
            }
            return
        }
        data.sessions.append(WorkSession(start: start, end: now >= end ? end : nil, breakLimitMinutes: data.limitMinutes, isAutomatic: true))
        data.sessions.sort { $0.start < $1.start }
        save()
    }
    func editSession(_ id: UUID, start: Date, end: Date?) {
        guard let i = data.sessions.firstIndex(where: { $0.id == id }), end == nil || end! > start else { return }
        data.sessions[i].start = start
        data.sessions[i].end = end
        data.sessions[i].isAutomatic = false
        save()
    }
    func removeSession(_ id: UUID) { data.sessions.removeAll { $0.id == id }; save() }
    func updateNote(_ note: LineNote) {
        guard let i = data.notes?.firstIndex(where: { $0.id == note.id }) else { return }
        data.notes?[i] = note
        save()
    }
    func editBreak(sessionID: UUID, breakID: UUID, start: Date, end: Date, kind: BreakKind? = nil) -> String? {
        guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }),
              let j = data.sessions[i].breaks.firstIndex(where: { $0.id == breakID }) else { return "Перекур не найден" }
        let session = data.sessions[i]
        let now = Date()
        guard start < end else { return "Конец должен быть позже начала" }
        guard end <= now else { return "Нельзя указать будущее время" }
        guard start >= session.start else { return "Перекур начинается раньше смены" }
        if let shiftEnd = session.end, end > shiftEnd { return "Перекур заканчивается после смены" }
        guard !session.breaks.contains(where: { other in
            other.id != breakID && start < (other.end ?? now) && end > other.start
        }) else { return "Время пересекается с другим перекуром" }
        let wasActive = data.sessions[i].breaks[j].end == nil
        data.sessions[i].breaks[j].start = start
        data.sessions[i].breaks[j].end = end
        if let kind { data.sessions[i].breaks[j].kind = kind }
        data.sessions[i].breaks.sort { $0.start < $1.start }
        save()
        if wasActive { BreakAlerts.stop() }
        return nil
    }
    func removeBreak(sessionID: UUID, breakID: UUID) {
        guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }),
              let j = data.sessions[i].breaks.firstIndex(where: { $0.id == breakID }) else { return }
        let wasActive = data.sessions[i].breaks[j].end == nil
        data.sessions[i].breaks.remove(at: j)
        save()
        if wasActive { BreakAlerts.stop() }
    }
    // Record a completed break retrospectively without starting a Live Activity.
    func addPastBreak(sessionID: UUID, start: Date, end: Date, kind: BreakKind = .smoke) -> String? {
        let now = Date()
        guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }) else { return "Смена не найдена" }
        let session = data.sessions[i]
        guard start < end else { return "Конец должен быть позже начала" }
        guard end <= now else { return "Нельзя добавить перекур из будущего" }
        guard start >= session.start else { return "Перекур начинается раньше смены" }
        if let sessionEnd = session.end, end > sessionEnd { return "Перекур заканчивается после смены" }
        guard !session.breaks.contains(where: { existing in
            let existingEnd = existing.end ?? now
            return start < existingEnd && end > existing.start
        }) else { return "Это время пересекается с другим перекуром" }
        data.sessions[i].breaks.append(BreakSession(start: start, end: end, kind: kind))
        data.sessions[i].breaks.sort { $0.start < $1.start }
        save()
        return nil
    }

    // The user is still on a break but forgot to press Start. Backdate the
    // break, preserve its real start, and refresh the Live Activity countdown.
    func startMissedBreak(sessionID: UUID, minutesAgo: Int) -> String? {
        let now = Date()
        let startedAt = now.addingTimeInterval(-Double(minutesAgo * 60))
        guard minutesAgo >= 1 && minutesAgo <= 180 else { return "Укажи от 1 до 180 минут" }
        guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }),
              data.sessions[i].start <= now,
              (data.sessions[i].end == nil || data.sessions[i].end! > now) else {
            return "Выбранная смена уже завершена"
        }
        let session = data.sessions[i]
        guard startedAt >= session.start else { return "Время раньше начала смены" }
        guard !session.breaks.contains(where: { other in
            let otherEnd = other.end ?? now
            return startedAt < otherEnd && now > other.start
        }) else { return "Перерыв пересекается с другим перекуром" }
        let spentBefore = breakSeconds(session, now: startedAt)
        let remainingAtStart = max(0, Double(session.breakLimitMinutes * 60) - spentBefore)
        data.sessions[i].breaks.append(BreakSession(start: startedAt, kind: .smoke))
        data.sessions[i].breaks.sort { $0.start < $1.start }
        save()
        BreakAlerts.requestPermission()
        BreakAlerts.start(remainingSeconds: remainingAtStart,
                          limitSeconds: Double(session.breakLimitMinutes * 60),
                          singleBreakSeconds: Double(perBreakLimitMinutes * 60),
                          breakStartedAt: startedAt,
                          kind: .smoke)
        return nil
    }

    // Next upcoming *new* shift. Handles the 8-day cycle and extra shifts,
    // including 20:00–08:00 overnight dates.
    func nextScheduledShift(after now: Date = Date()) -> (interval: DateInterval, extra: Bool)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var candidates: [(interval: DateInterval, extra: Bool)] = []
        for offset in 0...32 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let interval = regularInterval(on: day), interval.start > now else { continue }
            candidates.append((interval, false))
        }
        for extra in data.extras where extra.start > now {
            candidates.append((DateInterval(start: extra.start, end: extra.end), true))
        }
        return candidates.min(by: { $0.interval.start < $1.interval.start })
    }

    func replaceData(_ replacement: ShiftData) { data = replacement; save(); synchronize() }

    var activeBreak: BreakSession? { current?.breaks.last(where: { $0.end == nil }) }
    var isOnBreak: Bool { activeBreak != nil }
    var isOnLunch: Bool { activeBreak?.type == .lunch }
    func kindSeconds(_ kind: BreakKind, session: WorkSession, now: Date = Date()) -> TimeInterval {
        session.breaks.filter { $0.type == kind }.reduce(0) {
            $0 + max(0, ($1.end ?? min(now, session.end ?? now)).timeIntervalSince($1.start))
        }
    }
    func persistNow() { save() }
    func breakSeconds(_ session: WorkSession, now: Date = Date()) -> TimeInterval { session.breaks.reduce(0) { $0 + max(0, ( $1.end ?? min(now, session.end ?? now)).timeIntervalSince($1.start)) } }
    func workSeconds(_ session: WorkSession, now: Date = Date()) -> TimeInterval { max(0, (session.end ?? now).timeIntervalSince(session.start) - breakSeconds(session, now: now)) }
    func startWork() {
        guard current == nil else { return }
        undoAction = nil
        data.sessions.append(WorkSession(start: Date(), breakLimitMinutes: data.limitMinutes))
        save()
        BreakAlerts.requestPermission()
    }
    func endWork() {
        let now = Date()
        guard let i = data.sessions.lastIndex(where: { $0.start <= now && ($0.end == nil || $0.end! > now) }) else { return }
        undoAction = nil
        data.sessions[i].isAutomatic = false
        if let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) {
            data.sessions[i].breaks[j].end = now
        }
        data.sessions[i].end = now
        save()
        BreakAlerts.stop()
    }

    func toggleBreak() {
        if isOnBreak { finishBreak() }
        else { startBreak(kind: .smoke) }
    }

    func startBreak(kind: BreakKind) {
        synchronize()
        let now = Date()
        guard let i = data.sessions.lastIndex(where: { $0.start <= now && ($0.end == nil || $0.end! > now) }),
              !data.sessions[i].breaks.contains(where: { $0.end == nil }) else { return }
        let remaining = max(0, Double(data.sessions[i].breakLimitMinutes * 60) - breakSeconds(data.sessions[i], now: now))
        let item = BreakSession(start: now, kind: kind)
        data.sessions[i].breaks.append(item)
        undoAction = ShiftlyUndoAction(sessionID: data.sessions[i].id, breakID: item.id,
                                       operation: .started, kind: kind, issuedAt: now,
                                       label: kind == .lunch ? "Обед начат" : "Перекур начат")
        save()
        BreakAlerts.requestPermission()
        BreakAlerts.start(remainingSeconds: remaining,
                          limitSeconds: Double(data.sessions[i].breakLimitMinutes * 60),
                          singleBreakSeconds: Double((kind == .lunch ? 30 : perBreakLimitMinutes) * 60),
                          breakStartedAt: now, kind: kind)
    }

    func finishBreak() {
        synchronize()
        let now = Date()
        guard let i = data.sessions.lastIndex(where: { $0.start <= now && ($0.end == nil || $0.end! > now) }),
              let j = data.sessions[i].breaks.lastIndex(where: { $0.end == nil }) else { return }
        let item = data.sessions[i].breaks[j]
        data.sessions[i].breaks[j].end = now
        undoAction = ShiftlyUndoAction(sessionID: data.sessions[i].id, breakID: item.id,
                                       operation: .finished, kind: item.type, issuedAt: now,
                                       label: item.type == .lunch ? "Обед завершён" : "Перекур завершён")
        save()
        BreakAlerts.stop()
    }

    @discardableResult
    func undoLastBreakAction() -> Bool {
        guard let action = undoAction, Date() <= action.expiresAt,
              let i = data.sessions.firstIndex(where: { $0.id == action.sessionID }),
              let j = data.sessions[i].breaks.firstIndex(where: { $0.id == action.breakID }) else { return false }
        let item = data.sessions[i].breaks[j]
        let now = Date()
        switch action.operation {
        case .started:
            guard item.end == nil else { return false }
            data.sessions[i].breaks.remove(at: j)
            undoAction = nil
            save()
            BreakAlerts.stop()
        case .finished:
            guard item.end != nil,
                  abs(item.end!.timeIntervalSince(action.issuedAt)) < 3,
                  data.sessions[i].end == nil,
                  !data.sessions[i].breaks.contains(where: { $0.id != action.breakID && $0.end == nil }) else { return false }
            data.sessions[i].breaks[j].end = nil
            undoAction = nil
            save()
            let remainingAtStart = max(0, Double(data.sessions[i].breakLimitMinutes * 60) - breakSeconds(data.sessions[i], now: item.start))
            BreakAlerts.start(remainingSeconds: remainingAtStart,
                              limitSeconds: Double(data.sessions[i].breakLimitMinutes * 60),
                              singleBreakSeconds: Double((item.type == .lunch ? 30 : perBreakLimitMinutes) * 60),
                              breakStartedAt: item.start, kind: item.type)
        }
        return true
    }

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
        data.extras.append(ExtraShift(start: start, isNight: night)); data.extras.sort { $0.start < $1.start }; save(); synchronize(); ShiftReminders.schedule(store: self); return true
    }
    func removeExtra(_ id: UUID) { data.extras.removeAll { $0.id == id }; save(); ShiftReminders.schedule(store: self) }
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
    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
            ShiftlyShared.defaults.set(raw, forKey: key)
            if AutomaticBackups.save(data) {
                persistenceWarning = nil
            } else {
                persistenceWarning = "Не удалось обновить локальный JSON. Экспортируй резервную копию."
            }
        } else {
            persistenceWarning = "Ошибка кодирования данных Shiftly"
        }
        objectWillChange.send()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
