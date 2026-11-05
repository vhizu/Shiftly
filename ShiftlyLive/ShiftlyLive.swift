import SwiftUI
import WidgetKit
import ActivityKit



@main
struct ShiftlyLiveBundle: WidgetBundle {
    var body: some Widget { ShiftlyLiveWidget() }
}

// ActivityKit snapshots are not refreshed every minute in the background.
// Use SwiftUI's system-managed timer Text and date-based ProgressView to
// update the countdown on the Lock Screen and in all Dynamic Island regions.

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
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                         countsDown: true, showsHours: false)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Text("Всего:")
                        Text(timerInterval: context.attributes.startedAt...context.state.totalDeadline,
                             countsDown: true, showsHours: true)
                            .monospacedDigit()
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(timerInterval: context.attributes.startedAt...context.state.deadline,
                                 countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }.tint(.purple)
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
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                         countsDown: true, showsHours: false)
                        .font(.subheadline.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 60, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 12) {
                        // The large 1192px MascotIsland texture rendered as an
                        // empty grey tile in the expanded island on iPhone.
                        // IslandIconBreak is the small asset already verified
                        // in compact mode, and is kept in this extension target.
                        Image("IslandIconBreak")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                            .padding(5)
                            .background(Color.purple.opacity(0.11), in: Circle())
                            .overlay(Circle().stroke(Color.purple.opacity(0.30), lineWidth: 1))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Перекур · отдыхай 💜")
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                                .lineLimit(2)
                            ProgressView(timerInterval: context.attributes.startedAt...context.state.deadline,
                                         countsDown: true) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                                .tint(.purple)
                                .padding(5)
                                .background(Color.purple.opacity(0.09), in: Capsule())
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
                Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                     countsDown: true, showsHours: false)
                    .font(.caption2.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    // Fixed width avoids WidgetKit archiving/clipping the growing text.
                    .frame(width: 54, alignment: .trailing)
            } minimal: {
                Image("IslandIconBreak")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
    }
}
