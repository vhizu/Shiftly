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
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Shiftly · Перерыв", systemImage: "cup.and.saucer.fill")
                        .font(.headline).foregroundStyle(.purple)
                    Spacer()
                    Text("\(Int(context.state.limitSeconds / 60)) мин лимит")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true)
                    .font(.title.bold()).monospacedDigit()
                ProgressView(value: breakProgress(context.state)).tint(.purple)
                Button(intent: FinishBreakIntent()) {
                    Label("Вернулся к работе", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(.purple)
            }
            .padding(14)
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
