import SwiftUI
import WidgetKit
import ActivityKit

struct ShiftlyBreakAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var limitSeconds: Double
        var usedSeconds: Double
    }
    var startedAt: Date
}

@main
struct ShiftlyLiveBundle: WidgetBundle {
    var body: some Widget { ShiftlyLiveWidget() }
}

struct ShiftlyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftlyBreakAttributes.self) { context in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Shiftly · Перерыв", systemImage: "timer").font(.headline).foregroundStyle(.purple)
                    Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true)
                        .font(.title2.bold()).monospacedDigit()
                    Text("Осталось от лимита смены").font(.caption2).foregroundStyle(.secondary)
                    ProgressView(value: min(1, context.state.usedSeconds / max(1, context.state.limitSeconds))).tint(.purple)
                }
                Spacer(minLength: 4)
                Image("MascotLock").resizable().scaledToFill().frame(width: 94, height: 94)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.purple)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Перерыв", systemImage: "timer") }
                DynamicIslandExpandedRegion(.trailing) { Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Image("IslandExpandedBreak").resizable().scaledToFit().frame(width: 95, height: 85)
                        VStack(alignment: .leading) {
                            Text("Отдыхай, оператор 💜").font(.caption)
                            ProgressView(value: min(1, context.state.usedSeconds / max(1, context.state.limitSeconds))).tint(.purple)
                        }
                    }
                }
            } compactLeading: {
                Image("IslandIconBreak").resizable().scaledToFit().frame(width: 24, height: 24)
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true).monospacedDigit().frame(width: 54)
            } minimal: {
                Image("IslandIconBreak").resizable().scaledToFit().frame(width: 22, height: 22)
            }
        }
    }
}
