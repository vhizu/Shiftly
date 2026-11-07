import SwiftUI

// Payroll gets its own screen so pay calculations and month-scoped user inputs
// remain separate from the shift timer and the home tab.
struct PayrollView: View {
    @EnvironmentObject private var store: ShiftStore
    @StateObject private var settings = PayrollSettings()
    @State private var month = Date()
    @AppStorage("shiftly.salaryGoal") private var salaryGoal = 120_000.0

    var body: some View {
        NavigationStack {
            ScrollView {
                let slip = PayrollCalculator.statement(store: store, settings: settings, month: month)
                VStack(alignment: .leading, spacing: 16) {
                    monthSelector
                    PayrollHeroCard(slip: slip, goal: salaryGoal)
                    EarningsCalendarView(settings: settings, month: month)
                    PayrollBreakdownCard(slip: slip)
                    PayrollMonthControls(settings: settings, month: month, slip: slip)
                    PayrollConditionsCard(settings: settings, goal: $salaryGoal)
                    Text("Прогноз, не официальный расчётник. Смена 12 ч = 11 оплачиваемых; за полную ночную предполагается 7 оплачиваемых ночных часов. Правила премий, аванса и подработок могут отличаться — сравнивай с листком.")
                        .font(.caption).foregroundStyle(.white.opacity(0.67))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .shiftlyTabClearance()
            .background(ShiftlyBackdrop())
            .navigationTitle("Зарплата")
            .onAppear { settings.attach(store: store) }
        }
    }

    private var monthSelector: some View {
        HStack(spacing: 16) {
            Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }.accessibilityLabel("Предыдущий месяц")
            Spacer(minLength: 0)
            Text(ruMonth(month)).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }.accessibilityLabel("Следующий месяц")
        }
        .tint(Color(red: 0.78, green: 0.58, blue: 0.99))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .shiftlyGlass(radius: 20)
    }
}

private struct PayrollHeroCard: View {
    let slip: PaycheckBreakdown
    let goal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("ОСТАТОК К ВЫПЛАТЕ · ПРОГНОЗ", systemImage: "wallet.pass")
                .font(.caption2.bold()).tracking(1.0)
                .foregroundStyle(.white.opacity(0.74))
            Text(slip.toPay, format: .currency(code: "RUB"))
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.55).lineLimit(1)
            HStack(spacing: 10) {
                heroMetric("Начислено", slip.gross, symbol: "plus.circle.fill")
                heroMetric("После налога", slip.afterTax, symbol: "checkmark.seal.fill")
            }
            HStack {
                Text("Аванс · \(slip.actualAdvance ? "факт" : "прогноз")")
                Spacer()
                Text(slip.advance, format: .currency(code: "RUB"))
                    .fontWeight(.semibold)
            }
            .font(.subheadline).foregroundStyle(.white.opacity(0.81))
            ProgressView(value: min(1, max(0, slip.afterTax / max(1, goal))))
                .tint(Color(red: 0.75, green: 0.45, blue: 0.98))
        }
        .padding(18)
        .shiftlyGlass(radius: 24, emphasis: true)
    }

    private func heroMetric(_ title: String, _ amount: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
            Text(amount, format: .currency(code: "RUB"))
                .font(.subheadline.bold()).minimumScaleFactor(0.65).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PayrollBreakdownCard: View {
    let slip: PaycheckBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Расшифровка начислений", systemImage: "list.bullet.rectangle")
                .font(.headline)
            HStack(spacing: 8) {
                Label(String(format: "%.1f оплач. ч", slip.paidHours), systemImage: "clock")
                Spacer(minLength: 6)
                Label(String(format: "%.1f ночных", slip.nightHours), systemImage: "moon.stars")
            }
            .font(.caption).foregroundStyle(.white.opacity(0.75))
            Divider().overlay(Color.white.opacity(0.09))
            line("Часовая оплата", slip.base)
            line("Доплата за ночные", slip.night)
            line("Вредность", slip.hazard)
            line("Надбавка за подработки · оценка", slip.extra)
            line("Премия за прошлый месяц \(slip.premiumEstimated ? "· прогноз" : "· факт")", slip.premium)
            if slip.downtime > 0 { line("Простой", slip.downtime) }
            if slip.other != 0 { line("Другие начисления", slip.other) }
            Divider().overlay(Color.white.opacity(0.09))
            line("Всего начислено", slip.gross, strong: true)
            line("НДФЛ \(slip.actualTax ? "· факт" : "· оценка")", -slip.tax)
            if slip.taxableMeals > 0 {
                Text("Питание \(slip.taxableMeals.formatted(.currency(code: "RUB"))) включено только в налоговую базу, не в выплату.")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            line("Аванс \(slip.actualAdvance ? "· факт" : "· прогноз")", -slip.advance)
            Divider().overlay(Color.white.opacity(0.09))
            line("Остаток к выплате", slip.toPay, strong: true)
        }
        .padding(16)
        .shiftlyGlass(radius: 22)
    }

    private func line(_ title: String, _ value: Double, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(strong ? Color.white : Color.white.opacity(0.79))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(value, format: .currency(code: "RUB"))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .fontWeight(strong ? .bold : .medium)
        }
        .font(.subheadline)
    }
}

// Monthly manual overrides make variable premiums and advances auditable.
private struct PayrollMonthControls: View {
    @ObservedObject var settings: PayrollSettings
    let month: Date
    let slip: PaycheckBreakdown
    private var entry: PayrollMonthAdjustments { settings.month(month) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShiftlySectionHeader(title: "Премия за предыдущий месяц")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Прогноз, %").foregroundStyle(.white.opacity(0.86))
                    Spacer(minLength: 8)
                    PayrollNumberInput(value: Binding(
                        get: { entry.premiumPercent ?? settings.estimatedPremiumPercent },
                        set: { value in settings.editMonth(month) { $0.premiumPercent = value } }), width: 95)
                }
                Text("Ориентир — базовая оплата прошлого месяца: \(slip.premiumBasis.formatted(.currency(code: "RUB"))). Процент плавающий; это только предположение.")
                    .font(.caption).foregroundStyle(.white.opacity(0.68))
                Divider().overlay(Color.white.opacity(0.08))
                Toggle("Ввести фактическую премию", isOn: Binding(
                    get: { entry.actualPremium != nil },
                    set: { enabled in settings.editMonth(month) { $0.actualPremium = enabled ? slip.premium : nil } }))
                    .tint(.purple)
                if entry.actualPremium != nil {
                    valueRow("Сумма премии, ₽", value: optionalValue(\.actualPremium))
                }
            }
            .padding(16).shiftlyGlass(radius: 21)

            ShiftlySectionHeader(title: "Аванс · 1–15 число")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Предварительный аванс")
                    Spacer(minLength: 8)
                    Text(slip.advanceForecast, format: .currency(code: "RUB"))
                        .fontWeight(.semibold).minimumScaleFactor(0.7).lineLimit(1)
                }.font(.subheadline)
                Text("Прогноз: оплачиваемые часы смен 1–15 числа × ставка, затем оценка НДФЛ. Точная бухгалтерская формула пока неизвестна.")
                    .font(.caption).foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Color.white.opacity(0.08))
                Toggle("Ввести полученный аванс", isOn: Binding(
                    get: { entry.actualAdvance != nil },
                    set: { enabled in settings.editMonth(month) { $0.actualAdvance = enabled ? slip.advance : nil } }))
                    .tint(.purple)
                if entry.actualAdvance != nil {
                    valueRow("Аванс, ₽", value: optionalValue(\.actualAdvance))
                }
            }
            .padding(16).shiftlyGlass(radius: 21)

            ShiftlySectionHeader(title: "Дополнительные начисления")
            VStack(alignment: .leading, spacing: 13) {
                valueRow("Простой, ₽", value: monthValue(\.downtimeGross))
                valueRow("Другие начисления, ₽", value: monthValue(\.otherGross))
                valueRow("Питание для НДФЛ, ₽", value: monthValue(\.taxableMeals))
                Divider().overlay(Color.white.opacity(0.08))
                Toggle("Ввести фактический НДФЛ", isOn: Binding(
                    get: { entry.actualTax != nil },
                    set: { enabled in settings.editMonth(month) { $0.actualTax = enabled ? slip.tax : nil } }))
                    .tint(.purple)
                if entry.actualTax != nil {
                    valueRow("НДФЛ, ₽", value: optionalValue(\.actualTax))
                }
                Text("Данные сохраняются отдельно для каждого месяца. Питание не добавляется к деньгам на руки.")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            .padding(16).shiftlyGlass(radius: 21)
        }
    }

    private func monthValue(_ path: WritableKeyPath<PayrollMonthAdjustments, Double>) -> Binding<Double> {
        Binding(get: { settings.month(month)[keyPath: path] },
                set: { amount in settings.editMonth(month) { $0[keyPath: path] = amount } })
    }
    private func optionalValue(_ path: WritableKeyPath<PayrollMonthAdjustments, Double?>) -> Binding<Double> {
        Binding(get: { settings.month(month)[keyPath: path] ?? 0 },
                set: { amount in settings.editMonth(month) { $0[keyPath: path] = amount } })
    }
    private func valueRow(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 10) {
            Text(label).foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 8)
            PayrollNumberInput(value: value, width: 115)
        }.font(.subheadline)
    }
}

private struct PayrollConditionsCard: View {
    @ObservedObject var settings: PayrollSettings
    @Binding var goal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShiftlySectionHeader(title: "Условия оплаты")
            VStack(spacing: 13) {
                field("Ставка, ₽/ч", value: $settings.hourlyRate, width: 110)
                field("Оплачиваемых часов / 12 ч", value: $settings.paidHoursPerShift)
                field("Ночных оплач. часов / ночную", value: $settings.paidNightHoursPerShift)
                Divider().overlay(Color.white.opacity(0.08))
                field("Ночные, коэффициент", value: $settings.nightMultiplier)
                field("Вредность, %", value: $settings.hazardPercent)
                field("Подработка, коэфф. · уточнить", value: $settings.overtimeMultiplier)
                field("НДФЛ, % · ориентир", value: $settings.taxPercent)
                field("Прогноз премии, %", value: $settings.estimatedPremiumPercent)
                field("Цель за месяц, ₽", value: $goal, width: 115)
                if settings.monthlyBonus != 0 {
                    field("Старая постоянная надбавка, ₽", value: $settings.monthlyBonus, width: 115)
                }
                Text("Ставка 544,09 ₽, ночные 1,40 и вредность 4% — по октябрьскому листку. Коэффициент подработки 1,50 пока предположение. Перекуры и обед на эти часы повторно не влияют.")
                    .font(.caption).foregroundStyle(.white.opacity(0.67))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).shiftlyGlass(radius: 21)
        }
    }

    private func field(_ title: String, value: Binding<Double>, width: CGFloat = 94) -> some View {
        HStack(spacing: 10) {
            Text(title).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            PayrollNumberInput(value: value, width: width)
        }.font(.subheadline)
    }
}

private struct PayrollNumberInput: View {
    @Binding var value: Double
    var width: CGFloat = 110

    var body: some View {
        TextField("0", value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: width)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1))
            .accessibilityLabel("Значение")
    }
}
