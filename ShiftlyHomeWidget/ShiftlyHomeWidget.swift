import SwiftUI
import WidgetKit

struct ShiftlyEntry: TimelineEntry { let date: Date; let title: String; let detail: String }
struct ShiftlyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftlyEntry { ShiftlyEntry(date: Date(), title: "Shiftly 💜", detail: "Скоро смена") }
    func getSnapshot(in context: Context, completion: @escaping (ShiftlyEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftlyEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [entry(at: now)], policy: .after(now.addingTimeInterval(15 * 60))))
    }
    private func entry(at date: Date) -> ShiftlyEntry {
        let defaults = UserDefaults(suiteName: "group.com.shiftly.app") ?? .standard
        guard let raw = defaults.data(forKey: "shiftly.v1.data"),
              let data = try? JSONDecoder().decode(ShiftData.self, from: raw) else {
            return ShiftlyEntry(date: date, title: "Shiftly 💜", detail: "Открой приложение")
        }
        if let session = data.sessions.last(where: { $0.start <= date && ($0.end == nil || $0.end! > date) }) {
            let active = session.breaks.last?.end == nil && !session.breaks.isEmpty
            let used = session.breaks.reduce(0.0) { $0 + max(0, ($1.end ?? date).timeIntervalSince($1.start)) }
            return ShiftlyEntry(date: date, title: active ? "☕ Перерыв" : "💜 Работаю", detail: "Отдых: \(max(0, session.breakLimitMinutes - Int(used / 60))) мин")
        }
        return ShiftlyEntry(date: date, title: "💤 Отдыхаем", detail: "Следующая смена — по графику")
    }
}
struct ShiftlyHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShiftlyHome", provider: ShiftlyProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).font(.headline)
                Text(entry.detail).font(.caption)
                Spacer(minLength: 0)
                Text("SHIFTLY").font(.caption2.bold()).foregroundStyle(.purple)
            }
            .padding().containerBackground(.background, for: .widget)
        }.configurationDisplayName("Shiftly").description("Смена и лимит отдыха")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
@main struct ShiftlyHomeBundle: WidgetBundle { var body: some Widget { ShiftlyHomeWidget() } }
