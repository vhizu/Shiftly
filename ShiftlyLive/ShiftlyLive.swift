import SwiftUI
import WidgetKit
import ActivityKit

@main
struct ShiftlyLiveBundle: WidgetBundle {
    var body: some Widget { ShiftlyLiveWidget() }
}

// Live Activities are rendered by the system, not refreshed by app timers.
// Time text and the progress bar use date intervals to tick while locked.
private let islandViolet = Color(red: 0.81, green: 0.61, blue: 1)
private let islandBlue = Color(red: 0.48, green: 0.73, blue: 1)

struct ShiftlyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftlyBreakAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("IslandIconBreak")
                        .resizable().scaledToFit()
                        .frame(width: 38, height: 38)
                        .padding(3)
                        .background(islandViolet.opacity(0.13), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Shiftly · Перекур")
                            .font(.headline).foregroundStyle(.white)
                        Text("До окончания текущего перекура")
                            .font(.caption).foregroundStyle(Color.white.opacity(0.74))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "sparkles")
                        .foregroundStyle(islandViolet)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                         countsDown: true, showsHours: false)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ОСТАЛОСЬ ЗА СМЕНУ")
                            .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.74))
                        Text(timerInterval: context.attributes.startedAt...context.state.totalDeadline,
                             countsDown: true, showsHours: true)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(islandViolet)
                    }
                }
                ProgressView(timerInterval: context.attributes.startedAt...context.state.deadline,
                             countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(islandViolet)
                Button(intent: FinishBreakIntent()) {
                    Label("Вернулся к работе", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.70, green: 0.36, blue: 0.92))
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.095, green: 0.075, blue: 0.16))
            .activitySystemActionForegroundColor(islandViolet)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Перекур", systemImage: "cup.and.saucer.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                         countsDown: true, showsHours: false)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(islandViolet)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(width: 62, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Verified compact avatar, not the oversized mascot PNG
                        // that previously displayed as a grey square.
                        Image("IslandIconBreak")
                            .resizable().scaledToFit()
                            .frame(width: 49, height: 49)
                            .padding(4)
                            .background(
                                LinearGradient(colors: [islandViolet.opacity(0.27), islandBlue.opacity(0.10)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                            .overlay(Circle().stroke(islandViolet.opacity(0.48), lineWidth: 1))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 5) {
                                Text("Отдыхай 💜").foregroundStyle(.white)
                                Spacer(minLength: 0)
                                Text("SHIFTLY").foregroundStyle(islandViolet)
                            }
                            .font(.caption.bold())
                            ProgressView(timerInterval: context.attributes.startedAt...context.state.deadline,
                                         countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(islandViolet)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 3)
                }
            } compactLeading: {
                Image("IslandIconBreak")
                    .resizable().scaledToFit().frame(width: 24, height: 24)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                     countsDown: true, showsHours: false)
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.67)
                    .frame(width: 54, alignment: .trailing)
            } minimal: {
                Image("IslandIconBreak")
                    .resizable().scaledToFit().frame(width: 22, height: 22)
            }
        }
    }
}
