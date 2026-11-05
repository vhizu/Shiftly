import SwiftUI
import Foundation
import UniformTypeIdentifiers

// Preview and explicit confirmation ensure that an accidental import cannot
// silently erase an existing history. The saved data model is unchanged.
private struct BackupPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let data: ShiftData
    let byteCount: Int
    let modified: Date?

    var breakCount: Int { data.sessions.reduce(0) { $0 + $1.breaks.count } }
    var finishedCount: Int { data.sessions.filter { $0.end != nil }.count }
}

struct BackupCenterView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var importing = false
    @State private var exporting = false
    @State private var preview: BackupPreview?
    @State private var confirmRestore = false
    @State private var manuallySaved: URL?
    @State private var info: String?
    @State private var refreshID = 0

    private var availableFiles: [URL] {
        // An explicit refresh is used after creating a manual copy.
        _ = refreshID
        return AutomaticBackups.allFiles()
    }

    var body: some View {
        List {
            Section("Текущая история") {
                LabeledContent("Смен", value: "\(store.data.sessions.count)")
                LabeledContent("Перекуров", value: "\(store.data.sessions.reduce(0) { $0 + $1.breaks.count })")
                LabeledContent("Заметок", value: "\(store.data.notes?.count ?? 0)")

                Button {
                    do {
                        manuallySaved = try AutomaticBackups.createManual(store.data)
                        refreshID += 1
                        info = "Резервная копия создана. Сохрани её в «Файлы» или iCloud Drive для защиты от переустановки."
                    } catch {
                        info = "Не удалось создать копию: \(error.localizedDescription)"
                    }
                } label: {
                    Label("Создать копию сейчас", systemImage: "externaldrive.badge.plus")
                }

                if let manuallySaved {
                    ShareLink(item: manuallySaved) {
                        Label("Поделиться только что созданной копией", systemImage: "square.and.arrow.up")
                    }
                }

                Button { exporting = true } label: {
                    Label("Экспортировать текущую историю в «Файлы»", systemImage: "square.and.arrow.up.on.square")
                }
                Button { importing = true } label: {
                    Label("Выбрать JSON из «Файлов»", systemImage: "doc.badge.arrow.up")
                }
            }

            Section("Сохранённые копии на этом iPhone") {
                if availableFiles.isEmpty {
                    Text("Пока нет копий").foregroundStyle(.secondary)
                } else {
                    ForEach(availableFiles, id: \.path) { url in
                        HStack(spacing: 12) {
                            Button { openBackup(at: url, securityScope: false) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayName(for: url)).font(.subheadline.bold())
                                    Text(metadata(for: url))
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("Просмотреть содержимое")
                                        .font(.caption2).foregroundStyle(.purple)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(width: 36, height: 40)
                            }
                            .accessibilityLabel("Экспортировать \(url.lastPathComponent)")
                        }
                    }
                }
            }

            Section("Важно") {
                Text("Автоматические копии хранятся внутри приложения. При удалении Shiftly iOS может удалить их вместе с программой. Выгружай важные JSON в iCloud Drive или отдельную папку «Файлов».")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Перед каждым восстановлением создаётся отдельная страховочная копия текущих данных. Сначала появится предварительный просмотр выбранного файла.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let info, !info.isEmpty {
                Section("Результат") {
                    Text(info).font(.callout)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ShiftlyBackdrop())
        .navigationTitle("Резервные копии")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting,
                      document: ShiftBackupDocument(data: store.data),
                      contentType: .json,
                      defaultFilename: "Shiftly-1.7-backup") { result in
            switch result {
            case .success: info = "Выбрано место для экспорта JSON"
            case .failure(let error): info = "Ошибка экспорта: \(error.localizedDescription)"
            }
        }
        // public.item accepts files marked as generic 'data' by iOS providers.
        // Once chosen, the bytes are decoded and validated as ShiftData.
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            do {
                let url = try result.get()
                guard url.isFileURL && !url.hasDirectoryPath else {
                    info = "Нужно выбрать файл JSON, а не папку"
                    return
                }
                openBackup(at: url, securityScope: true)
            } catch {
                info = "Не удалось выбрать файл: \(error.localizedDescription)"
            }
        }
        .sheet(item: $preview) { candidate in
            NavigationStack {
                Form {
                    Section("Выбранный файл") {
                        Text(candidate.fileName)
                            .font(.subheadline).textSelection(.enabled)
                        LabeledContent("Размер", value: ByteCountFormatter.string(fromByteCount: Int64(candidate.byteCount), countStyle: .file))
                        if let modified = candidate.modified {
                            LabeledContent("Изменён", value: ruDate(modified))
                        }
                    }
                    Section("Что внутри") {
                        LabeledContent("Смен", value: "\(candidate.data.sessions.count)")
                        LabeledContent("Завершённых смен", value: "\(candidate.finishedCount)")
                        LabeledContent("Перекуров", value: "\(candidate.breakCount)")
                        LabeledContent("Заметок", value: "\(candidate.data.notes?.count ?? 0)")
                        LabeledContent("Общий лимит", value: "\(candidate.data.limitMinutes) мин")
                        if let last = candidate.data.sessions.map(\.start).max() {
                            LabeledContent("Последняя смена", value: ruDate(last))
                        }
                    }
                    Section {
                        Button("Восстановить данные из этой копии", role: .destructive) {
                            confirmRestore = true
                        }
                    } footer: {
                        Text("Все текущие смены и перекуры будут заменены данными этой копии. Перед заменой Shiftly сохранит страховочный снимок.")
                    }
                }
                .navigationTitle("Проверка копии")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { preview = nil }
                    }
                }
                .confirmationDialog("Заменить текущую историю?", isPresented: $confirmRestore,
                                    titleVisibility: .visible) {
                    Button("Восстановить", role: .destructive) { restore(candidate) }
                    Button("Отмена", role: .cancel) { }
                } message: {
                    Text("Текущая история будет заменена данными из \(candidate.fileName). Это действие нельзя отменить, но перед ним создаётся локальная копия.")
                }
            }
        }
    }

    private func displayName(for url: URL) -> String {
        if url.lastPathComponent == "Shiftly-latest.json" { return "Последнее автосохранение" }
        if url.lastPathComponent.contains("before-restore") { return "Перед восстановлением" }
        if url.lastPathComponent.hasPrefix("Shiftly-manual-") { return "Ручная копия" }
        return "Автоматическая копия"
    }

    private func metadata(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let date = values?.contentModificationDate.map(ruDate) ?? "Дата неизвестна"
        let size = ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
        return "\(date) · \(size)"
    }

    private func openBackup(at url: URL, securityScope: Bool) {
        let scoped = securityScope && url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            guard raw.count > 0 && raw.count < 40_000_000 else {
                info = "Файл пустой или слишком большой (максимум 40 МБ)"
                return
            }
            let parsed = try JSONDecoder().decode(ShiftData.self, from: raw)
            guard parsed.limitMinutes > 0 && parsed.limitMinutes <= 1440 else {
                info = "Некорректный лимит смены в копии"
                return
            }
            guard parsed.sessions.allSatisfy({ session in
                session.breakLimitMinutes > 0 &&
                (session.end == nil || session.end! > session.start) &&
                session.breaks.allSatisfy({ entry in
                    entry.start >= session.start &&
                    (entry.end == nil || entry.end! >= entry.start)
                })
            }) else {
                info = "В копии найдены некорректные даты смен или перекуров"
                return
            }
            let metadata = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            preview = BackupPreview(fileName: url.lastPathComponent,
                                    data: parsed,
                                    byteCount: raw.count,
                                    modified: metadata?.contentModificationDate)
            info = nil
        } catch {
            info = "Файл не похож на резервную копию Shiftly: \(error.localizedDescription)"
        }
    }

    private func restore(_ candidate: BackupPreview) {
        guard AutomaticBackups.saveBeforeRestore(store.data) else {
            info = "Не удалось создать страховочную копию. Восстановление отменено."
            preview = nil
            return
        }
        store.replaceData(candidate.data)
        preview = nil
        refreshID += 1
        manuallySaved = nil
        info = "Восстановлено: \(candidate.data.sessions.count) смен, \(candidate.breakCount) перекуров. Старые данные сохранены в страховочной копии."
    }
}
