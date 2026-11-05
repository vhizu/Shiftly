import SwiftUI
import WidgetKit
import AppIntents

struct ShiftlyEntry: TimelineEntry {
    let date: Date
    let title: String
    let detail: String
    let canStart: Bool
    let remaining: Int?
}

struct ShiftlyProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftlyEntry {
        ShiftlyEntry(date: Date(), title: "Скоро смена", detail: "Shiftly 💜", canStart: false, remaining: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (ShiftlyEntry) -> Void) {
        completion(entry(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftlyEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [entry(at: now)], policy: .after(now.addingTimeInterval(5 * 60))))
    }
    private func entry(at date: Date) -> ShiftlyEntry {
        let defaults = UserDefaults(suiteName: "group.com.shiftly.app") ?? .standard
        guard let raw = defaults.data(forKey: "shiftly.v1.data"),
              let data = try? JSONDecoder().decode(ShiftData.self, from: raw) else {
            return ShiftlyEntry(date: date, title: "Время отдыха", detail: "Открой Shiftly", canStart: false, remaining: nil)
        }
        if let session = data.sessions.last(where: { $0.start <= date && ($0.end == nil || $0.end! > date) }) {
            let active = session.breaks.last?.end == nil && !session.breaks.isEmpty
            let used = session.breaks.reduce(0.0) { $0 + max(0, ($1.end ?? date).timeIntervalSince($1.start)) }
            let remaining = max(0, session.breakLimitMinutes - Int(used / 60))
            let lunch = session.breaks.last(where: { $0.end == nil })?.type == .lunch
            return ShiftlyEntry(date: date, title: active ? (lunch ? "Идёт обед" : "Идёт перекур") : "Смена идёт",
                               detail: active ? "Вернись через приложение" : "Можно отдохнуть",
                               canStart: !active, remaining: remaining)
        }
        return ShiftlyEntry(date: date, title: "Выходной", detail: "Следующая смена в графике", canStart: false, remaining: nil)
    }
}

struct ShiftlyHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShiftlyHome", provider: ShiftlyProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold()).foregroundStyle(Color(red: 0.88, green: 0.71, blue: 1))
                    Text("SHIFTLY")
                        .font(.caption2.bold()).tracking(1.4).foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                Text(entry.title)
                    .font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if let remaining = entry.remaining {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(remaining)").font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("мин осталось").font(.caption2.bold())
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.75)
                } else {
                    Text(entry.detail)
                        .font(.caption).foregroundStyle(.white.opacity(0.80))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if entry.canStart {
                    Button(intent: StartBreakIntent()) {
                        Label("Перекур", systemImage: "cup.and.saucer.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.36, blue: 0.89))
                } else {
                    Text(entry.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.76)).lineLimit(1)
                }
            }
            .padding(13)
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(red: 0.28, green: 0.17, blue: 0.45),
                                        Color(red: 0.09, green: 0.13, blue: 0.30),
                                        Color(red: 0.07, green: 0.06, blue: 0.15)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .configurationDisplayName("Shiftly")
        .description("Смена и лимит отдыха")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main struct ShiftlyHomeBundle: WidgetBundle {
    var body: some Widget { ShiftlyHomeWidget() }
}
