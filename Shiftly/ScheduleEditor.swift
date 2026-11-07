import SwiftUI

// Three-state repeating pattern editor. No change is persisted until Save is tapped.
struct ScheduleEditorView: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State private var anchor = ShiftCycle.original.anchor
    @State private var days = ShiftCycle.original.days
    @State private var error: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Начало цикла", systemImage: "calendar.badge.clock")
                        .font(.headline)
                    DatePicker("Первый день", selection: $anchor, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                    Text("Первый квадрат соответствует выбранной дате. Дальше эта последовательность повторяется бесконечно.")
                        .font(.caption).foregroundStyle(.white.opacity(0.73))
                }
                .padding(16).shiftlyGlass(radius: 22)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Label("Дни цикла", systemImage: "repeat")
                            .font(.headline)
                        Spacer()
                        Text("\(days.count) дн.")
                            .font(.subheadline.bold()).foregroundStyle(.white.opacity(0.7))
                    }
                    Text("Нажимай на день: Д → Н → В. Можно сделать цикл любой длины от 1 до 31 дня.")
                        .font(.caption).foregroundStyle(.white.opacity(0.72))
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(days.indices, id: \.self) { index in
                            Button {
                                let type = days[index]
                                days[index] = type == .day ? .night : type == .night ? .off : .day
                                ShiftlyFeedback.light()
                            } label: {
                                VStack(spacing: 5) {
                                    Text("\(index + 1)")
                                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                    Text(days[index].shortLabel)
                                        .font(.title2.bold())
                                        .foregroundStyle(scheduleColor(days[index]))
                                    Text(days[index] == .day ? "08–20" : days[index] == .night ? "20–08" : "Отдых")
                                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.68))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 78)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(scheduleColor(days[index]).opacity(0.40), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("День \(index + 1): \(days[index].title). Изменить")
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            if days.count < 31 { days.append(.off); ShiftlyFeedback.light() }
                        } label: {
                            Label("Добавить", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(days.count >= 31)
                        Button {
                            if days.count > 1 { days.removeLast(); ShiftlyFeedback.light() }
                        } label: {
                            Label("Убрать", systemImage: "minus")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(days.count <= 1)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.88))
                }
                .padding(16).shiftlyGlass(radius: 22)

                VStack(alignment: .leading, spacing: 9) {
                    Label("Предпросмотр следующего круга", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                    Text("После дня \(days.count) снова будет первый день выбранной последовательности.")
                        .font(.caption).foregroundStyle(.white.opacity(0.70))
                    HStack(spacing: 6) {
                        ForEach(0..<min(days.count, 10), id: \.self) { index in
                            Text(days[index].shortLabel)
                                .font(.subheadline.bold())
                                .foregroundStyle(scheduleColor(days[index]))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(16).shiftlyGlass(radius: 22)

                Text("График изменит будущие смены, напоминания и прогноз зарплаты. История фактически отработанных смен сохраняется. Подработки не удаляются и не дублируются.")
                    .font(.caption).foregroundStyle(.white.opacity(0.77))

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .padding(12).shiftlyGlass(radius: 15)
                }
                Button {
                    if let message = store.setCycle(anchor: anchor, days: days) {
                        error = message
                        ShiftlyFeedback.medium()
                    } else {
                        ShiftlyFeedback.success()
                        dismiss()
                    }
                } label: {
                    Label("Сохранить цикл", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShiftlyPrimaryButtonStyle())
            }
            .padding(16)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .background(ShiftlyBackdrop())
        .navigationTitle("Мой график")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let cycle = store.data.customSchedule {
                anchor = cycle.anchor
                days = cycle.days
            }
        }
    }
}

struct EditableScheduleDay: Identifiable {
    let id = UUID()
    let date: Date
}

struct ScheduleDayEditor: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var chosen: ShiftDayKind = .off
    @State private var issue: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "ru_RU"))))
                            .font(.title3.bold())
                        Text("По циклу: \(store.baseDayKind(on: date).title)")
                            .font(.caption).foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).shiftlyGlass(radius: 20)

                    VStack(spacing: 0) {
                        ForEach(ShiftDayKind.allCases) { kind in
                            Button {
                                chosen = kind
                                ShiftlyFeedback.light()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(kind.shortLabel)
                                        .font(.headline).foregroundStyle(scheduleColor(kind))
                                        .frame(width: 30)
                                    Text(kind.title).foregroundStyle(.white)
                                    Spacer()
                                    if chosen == kind { Image(systemName: "checkmark.circle.fill").foregroundStyle(.purple) }
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if kind != ShiftDayKind.allCases.last { Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .shiftlyGlass(radius: 20)

                    if let issue {
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button {
                        let result = store.setDayOverride(on: date, kind: chosen)
                        if let result { issue = result } else { ShiftlyFeedback.success(); dismiss() }
                    } label: {
                        Label("Сохранить день", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ShiftlyPrimaryButtonStyle())

                    if store.dayOverride(on: date) != nil {
                        Button("Вернуть день по циклу") {
                            let result = store.setDayOverride(on: date, kind: nil)
                            if let result { issue = result } else { dismiss() }
                        }
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    Text("Редактирование календаря не меняет уже отработанные смены. При конфликте с подработкой сохранение не выполнится.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.70))
                }
                .padding(16)
            }
            .background(ShiftlyBackdrop())
            .navigationTitle("Изменить день")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
            .onAppear { chosen = store.dayKind(on: date) }
        }
    }
}

private func scheduleColor(_ kind: ShiftDayKind) -> Color {
    switch kind {
    case .day: return Color(red: 0.38, green: 0.85, blue: 0.66)
    case .night: return Color(red: 0.80, green: 0.55, blue: 0.96)
    case .off: return .white.opacity(0.7)
    case .vacation: return .cyan
    case .sick: return .orange
    }
}
