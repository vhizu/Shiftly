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

private func breakProgress(_ state: ShiftlyBreakAttributes.ContentState) -> Double {
    min(1, max(0, state.usedSeconds / max(1, state.limitSeconds)))
}

private func remainingMinutes(until deadline: Date, at now: Date) -> Int {
    max(0, Int(ceil(deadline.timeIntervalSince(now) / 60)))
}

struct ShiftlyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftlyBreakAttributes.self) { context in
            HStack(alignment: .center, spacing: 12) {
                Image("MascotLock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 112, alignment: .bottom)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Shiftly · Перерыв", systemImage: "timer")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)

                    Text(timerInterval: Date()...max(Date(), context.state.deadline),
                         countsDown: true)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Осталось от лимита смены")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ProgressView(value: breakProgress(context.state))
                        .tint(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.purple)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Перерыв", systemImage: "timer")
                        .font(.subheadline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...max(Date(), context.state.deadline),
                         countsDown: true)
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 12) {
                        Image("MascotIsland")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 112, height: 95, alignment: .bottom)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Отдыхай, оператор 💜")
                                .font(.caption)
                                .lineLimit(2)
                            ProgressView(value: breakProgress(context.state))
                                .tint(.purple)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                Image("IslandIconBreak")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text("\(remainingMinutes(until: context.state.deadline, at: timeline.date))м")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 43, alignment: .trailing)
            } minimal: {
                Image("IslandIconBreak")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
    }
}