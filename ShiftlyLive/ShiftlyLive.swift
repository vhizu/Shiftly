import SwiftUI
import WidgetKit
import ActivityKit



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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image("IslandIconBreak")
                        .resizable().scaledToFit().frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Shiftly · Перерыв").font(.headline).foregroundStyle(.purple)
                        Text("До конца текущего перекура").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("Лимит смены: \(Int(context.state.limitSeconds / 60)) мин")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline, countsDown: true)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        Text("Всего: \(remainingMinutes(until: context.state.totalDeadline, at: timeline.date))м")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: breakProgress(context.state)).tint(.purple)
                Button(intent: FinishBreakIntent()) {
                    Label("Вернулся к работе", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.purple)
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.06, green: 0.05, blue: 0.10))
            .activitySystemActionForegroundColor(.purple)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Перерыв", systemImage: "timer")
                        .font(.subheadline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        Text("\(remainingMinutes(until: context.state.deadline, at: timeline.date))м")
                            .font(.subheadline.bold().monospacedDigit())
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 12) {
                        Image("MascotIsland")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 112, height: 95, alignment: .bottom)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Перекур · отдыхай 💜")
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
                .frame(width: 48, alignment: .trailing)
            } minimal: {
                Image("IslandIconBreak")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
    }
}
