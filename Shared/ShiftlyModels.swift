import Foundation

struct WorkSession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    var breaks: [BreakSession] = []
    var breakLimitMinutes: Int
    var isAutomatic: Bool? = nil
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
struct LineNote: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var stream: String = "910"
    var category: String = "Заметка"
    var details: String = ""
    var durationMinutes: Int = 0
}
struct ShiftData: Codable {
    var limitMinutes = 120
    var sessions: [WorkSession] = []
    var extras: [ExtraShift] = []
    var notes: [LineNote]? = nil
    var autoEnabled: Bool? = nil
    var remindEnabled: Bool? = nil
    // Optional: decoding backups made before 1.5 remains compatible.
    var perBreakLimitMinutes: Int? = nil
}
