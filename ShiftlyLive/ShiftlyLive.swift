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
            // Lock Screen Live Activities can be clipped above ~160 pt.
            // Keep everything compact and within the system's presentation.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image("IslandIconBreak")
                        .resizable().scaledToFit()
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.breakType == .lunch ? "Shiftly · Обед" : "Shiftly · Перекур")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.breakType == .lunch ? "Обед · 30 минут" : "Текущий перекур")
                            .font(.caption2).foregroundStyle(Color.white.opacity(0.72))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "sparkles")
                        .font(.caption).foregroundStyle(islandViolet)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(timerInterval: context.attributes.startedAt...context.state.deadline,
                         countsDown: true, showsHours: false)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("ЗА СМЕНУ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(timerInterval: context.attributes.startedAt...context.state.totalDeadline,
                             countsDown: true, showsHours: true)
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(islandViolet)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(width: 110, alignment: .trailing)
                }
                ProgressView(timerInterval: context.attributes.startedAt...context.state.deadline,
                             countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(islandViolet)
                Button(intent: FinishBreakIntent()) {
                    Label(context.state.breakType == .lunch ? "Завершить обед" : "Вернулся к работе", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 35)
                        .background(
                            LinearGradient(colors: [islandViolet, Color(red: 0.57, green: 0.36, blue: 0.90)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .activityBackgroundTint(Color(red: 0.075, green: 0.055, blue: 0.135))
            .activitySystemActionForegroundColor(islandViolet)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.breakType == .lunch ? "Обед" : "Перекур", systemImage: context.state.breakType.icon)
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
                                Text(context.state.breakType == .lunch ? "Приятного аппетита 🍱" : "Отдыхай 💜").foregroundStyle(.white)
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
