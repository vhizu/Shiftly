import SwiftUI

private let workNoteKinds = ["Заметка", "Простой", "Неисправность", "Ремонт"]

struct WorkNotesView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var equipment = ""
    @State private var category = "Заметка"
    @State private var details = ""
    @State private var duration = 0
    @State private var search = ""
    @State private var editing: LineNote?
    @State private var mascotTap = 0

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    private var results: [LineNote] {
        store.notes.filter { note in
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return q.isEmpty || [note.stream, note.category, note.details].contains { $0.localizedCaseInsensitiveContains(q) }
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ShiftlySectionHeader(title: "Новая запись")
                Button {
                    mascotTap += 1
                    ShiftlyFeedback.light()
                } label: {
                    Label(MascotLines.phrase(for: .notes, index: mascotTap), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .shiftlyGlass(radius: 17)
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Оборудование / ручей").font(.subheadline.weight(.semibold))
                        TextField("Необязательно · 910, TNA, Yamato…", text: $equipment)
                            .textInputAutocapitalization(.sentences)
                            .padding(12)
                            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Тип события").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: columns, spacing: 9) {
                        ForEach(workNoteKinds, id: \.self) { kind in
                            Button {
                                category = kind
                                ShiftlyFeedback.light()
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: symbol(for: kind))
                                    Text(kind).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .font(.subheadline.weight(category == kind ? .semibold : .regular))
                                .foregroundStyle(category == kind ? .white : .white.opacity(0.78))
                                .frame(maxWidth: .infinity).frame(height: 45)
                                .background(category == kind ? Color.purple.opacity(0.34) : Color.white.opacity(0.055),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                                    category == kind ? Color.purple.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("Описание").font(.subheadline.weight(.semibold))
                    TextField("Что произошло?", text: $details, axis: .vertical)
                        .lineLimit(3...7)
                        .padding(12)
                        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
                    if category != "Заметка" {
                        Stepper(value: $duration, in: 0...720, step: 1) {
                            HStack {
                                Label("Длительность простоя", systemImage: "timer")
                                Spacer()
                                Text("\(duration) мин").fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                    Button {
                        store.addNote(LineNote(date: Date(),
                                               stream: equipment.trimmingCharacters(in: .whitespacesAndNewlines),
                                               category: category,
                                               details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                                               durationMinutes: category == "Заметка" ? 0 : duration))
                        details = ""; duration = 0
                        ShiftlyFeedback.success()
                    } label: {
                        Label("Сохранить запись", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ShiftlyPrimaryButtonStyle())
                    .disabled(details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16).shiftlyGlass(radius: 22)

                ShiftlySectionHeader(title: "История записей")
                if results.isEmpty {
                    Text(search.isEmpty ? "Записей пока нет" : "По запросу ничего не найдено")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).shiftlyGlass(radius: 18)
                }
                ForEach(results) { note in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .top) {
                            Label(note.category, systemImage: symbol(for: note.category))
                                .font(.subheadline.bold())
                            Spacer(minLength: 8)
                            if note.durationMinutes > 0 {
                                Text("\(note.durationMinutes) мин")
                                    .font(.caption.bold()).foregroundStyle(.orange)
                            }
                        }
                        if !note.stream.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label(note.stream, systemImage: "wrench.and.screwdriver")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Text(note.details).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                        Text(ruDate(note.date)).font(.caption2).foregroundStyle(.white.opacity(0.55))
                        HStack(spacing: 15) {
                            Button { editing = note } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            Spacer()
                            Button(role: .destructive) { store.removeNote(note.id) } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .font(.caption.bold())
                    }
                    .padding(15).shiftlyGlass(radius: 20)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .background(ShiftlyBackdrop())
        .navigationTitle("Рабочие заметки")
        .searchable(text: $search, prompt: "Поиск по оборудованию и тексту")
        .sheet(item: $editing) { note in WorkNoteEditor(note: note) }
    }
}

private func symbol(for category: String) -> String {
    switch category {
    case "Простой", "Остановка": return "timer"
    case "Неисправность": return "exclamationmark.triangle"
    case "Ремонт": return "wrench.adjustable"
    case "Переналадка": return "arrow.triangle.2.circlepath"
    case "Замена рулона": return "shippingbox"
    case "Запуск": return "play.circle"
    default: return "note.text"
    }
}

struct WorkNoteEditor: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State var note: LineNote

    var body: some View {
        NavigationStack {
            Form {
                Section("Запись") {
                    DatePicker("Время", selection: $note.date)
                    TextField("Оборудование / ручей", text: $note.stream)
                    Picker("Тип события", selection: $note.category) {
                        ForEach(Array(Set(workNoteKinds + [note.category])).sorted(), id: \.self) { kind in
                            Text(kind).tag(kind)
                        }
                    }
                    TextField("Описание", text: $note.details, axis: .vertical)
                        .lineLimit(3...7)
                }
                Section("Простой") {
                    Stepper("\(note.durationMinutes) минут", value: $note.durationMinutes, in: 0...720)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShiftlyBackdrop())
            .navigationTitle("Изменить заметку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { store.updateNote(note); dismiss() }
                        .disabled(note.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
