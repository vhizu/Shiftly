import SwiftUI
import Foundation
import UniformTypeIdentifiers
import UIKit

// Some Files providers label JSON as public.data or generic public.item.
// A copy-style document picker accepts these files even when strict UTType.json
// importers display them disabled. The bytes, not the extension, are validated.
private struct ShiftlyJSONPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .data, .json, .plainText], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var owner: ShiftlyJSONPicker
        init(owner: ShiftlyJSONPicker) { self.owner = owner }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { owner.onCancel(); return }
            owner.onPick(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { owner.onCancel() }
    }
}

private struct BackupPreview: Identifiable {
    let id = UUID()
    let name: String
    let data: ShiftData
    let bytes: Int
    let modified: Date?
    var breaks: Int { data.sessions.reduce(0) { $0 + $1.breaks.count } }
}

struct BackupCenterView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var exporting = false
    @State private var exportingCSV = false
    @State private var localFiles: [URL] = []
    @State private var folderFiles: [URL] = []
    @State private var externalFolder: URL?
    @State private var folderScopeActive = false
    @State private var selectedFile: URL?
    @State private var preview: BackupPreview?
    @State private var confirmRestore = false
    @State private var info: String?
    @State private var manualCopy: URL?
    @State private var refreshed: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 11) {
                    Label("ТВОИ ДАННЫЕ", systemImage: "externaldrive.fill")
                        .font(.caption.bold()).foregroundStyle(.purple)
                    Text("Резервные копии")
                        .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    HStack {
                        summary("Смен", "\(store.data.sessions.count)")
                        summary("Перекуров", "\(store.data.sessions.reduce(0) { $0 + $1.breaks.count })")
                        summary("Заметок", "\(store.data.notes?.count ?? 0)")
                    }
                }
                .padding(17).shiftlyGlass(radius: 22, emphasis: true)

                ShiftlySectionHeader(title: "Восстановление")
                Button { showFilePicker = true } label: {
                    Label("Загрузить JSON из «Файлов»", systemImage: "square.and.arrow.down.on.square")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(ShiftlyPrimaryButtonStyle())

                Text("Открой любую резервную копию. Shiftly проверит её перед восстановлением.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.horizontal, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    backupAction("Выбрать папку", subtitle: "Найти все копии", symbol: "folder.badge.plus", tint: .cyan) {
                        showFolderPicker = true
                    }
                    backupAction("Обновить файлы", subtitle: "Повторный поиск", symbol: "arrow.clockwise", tint: .mint) {
                        refreshFiles()
                    }
                    backupAction("Вставить JSON", subtitle: "Из буфера обмена", symbol: "doc.on.clipboard", tint: .orange) {
                        importFromClipboard()
                    }
                    backupAction("Локальный снимок", subtitle: "Создать страховку", symbol: "externaldrive.badge.plus", tint: .pink) {
                        createLocalCopy()
                    }
                }
                if let refreshed {
                    Text("Обновлено: " + ruDate(refreshed))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.70))
                        .padding(.horizontal, 4)
                }
                ShiftlySectionHeader(title: "Сохранение и экспорт")
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    backupAction("Сохранить JSON", subtitle: "В iCloud или «Файлы»", symbol: "square.and.arrow.up", tint: .green) {
                        exporting = true
                    }
                    backupAction("Экспорт CSV", subtitle: "Таблица истории", symbol: "tablecells", tint: .blue) {
                        exportingCSV = true
                    }
                }
                if let manualCopy {
                    ShareLink(item: manualCopy) {
                        Label("Поделиться последней копией", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .shiftlyGlassControl(radius: 17)
                    }
                }

                ShiftlySectionHeader(title: "Найденные JSON в выбранной папке")
                if let externalFolder {
                    Text(externalFolder.lastPathComponent)
                        .font(.caption).foregroundStyle(Color.white.opacity(0.75))
                        .padding(.horizontal, 2)
                    if folderFiles.isEmpty {
                        emptyState("JSON-файлов в выбранной папке не найдено. Попробуй обновить список или выбрать сам файл.")
                    } else {
                        ForEach(folderFiles, id: \.path) { file in
                            backupRow(file, external: true)
                        }
                    }
                } else {
                    emptyState("Выбери папку с резервными копиями. Для обычного файла используй кнопку «Выбрать JSON» выше.")
                }

                ShiftlySectionHeader(title: "Копии внутри Shiftly")
                if localFiles.isEmpty {
                    emptyState("Локальных копий пока нет")
                } else {
                    ForEach(localFiles, id: \.path) { file in
                        backupRow(file, external: false)
                    }
                }

                if let info {
                    Text(info).font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(14).shiftlyGlass(radius: 17)
                }
                Text("Важно: iOS не позволяет приложению видеть произвольные папки без твоего разрешения. После выбора папки нажми «Обновить список». Перед восстановлением создаётся страховочная копия. Локальные копии могут удалиться вместе с приложением.")
                    .font(.caption).foregroundStyle(Color.white.opacity(0.72))
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(ShiftlyBackdrop())
        .navigationTitle("Бэкапы")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshFiles() }
        .onDisappear { releaseFolder(); externalFolder = nil; folderFiles = [] }
        .sheet(isPresented: $showFilePicker, onDismiss: {
            if let url = selectedFile {
                selectedFile = nil
                openBackup(at: url, withSecurityScope: true)
            }
        }) {
            ShiftlyJSONPicker(onPick: { url in selectedFile = url; showFilePicker = false },
                              onCancel: { showFilePicker = false })
        }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            do {
                let folder = try result.get()
                guard ((try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? folder.hasDirectoryPath) else {
                    info = "Выбран файл, а не папка. Для JSON используй отдельную кнопку."
                    return
                }
                releaseFolder()
                folderScopeActive = folder.startAccessingSecurityScopedResource()
                externalFolder = folder
                refreshFiles()
            } catch {
                info = "Не удалось открыть папку: \(error.localizedDescription). Можно выбрать отдельный JSON-файл."
            }
        }
        .fileExporter(isPresented: $exporting,
                      document: ShiftBackupDocument(data: store.data),
                      contentType: .json,
                      defaultFilename: "Shiftly-1.9.1-backup") { result in
            switch result {
            case .success: info = "Копия экспортирована. Проверь её в выбранной папке «Файлов»."
            case .failure(let error): info = "Ошибка экспорта: \(error.localizedDescription)"
            }
        }
        .fileExporter(isPresented: $exportingCSV,
                      document: ShiftCSVDocument(data: store.data),
                      contentType: .commaSeparatedText,
                      defaultFilename: "Shiftly-1.9.1-export") { result in
            switch result {
            case .success: info = "CSV экспортирован в «Файлы»."
            case .failure(let error): info = "Ошибка CSV: \(error.localizedDescription)"
            }
        }
        .sheet(item: $preview) { candidate in
            NavigationStack {
                Form {
                    Section("Файл") {
                        Text(candidate.name).font(.subheadline).textSelection(.enabled)
                        LabeledContent("Размер", value: ByteCountFormatter.string(fromByteCount: Int64(candidate.bytes), countStyle: .file))
                        if let modified = candidate.modified { LabeledContent("Изменён", value: ruDate(modified)) }
                    }
                    Section("Содержимое") {
                        LabeledContent("Смен", value: "\(candidate.data.sessions.count)")
                        LabeledContent("Перекуров", value: "\(candidate.breaks)")
                        LabeledContent("Заметок", value: "\(candidate.data.notes?.count ?? 0)")
                        LabeledContent("Лимит", value: "\(candidate.data.limitMinutes) мин")
                        if let last = candidate.data.sessions.map(\.start).max() {
                            LabeledContent("Последняя смена", value: ruDate(last))
                        }
                    }
                    Section {
                        Button("Восстановить эту копию", role: .destructive) { confirmRestore = true }
                    } footer: {
                        Text("Текущая история будет заменена только после создания страховочной копии.")
                    }
                }
                .navigationTitle("Проверка JSON")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { preview = nil } } }
                .confirmationDialog("Заменить текущую историю?", isPresented: $confirmRestore) {
                    Button("Восстановить", role: .destructive) { restore(candidate) }
                    Button("Отмена", role: .cancel) { }
                } message: { Text("Сначала Shiftly сохранит текущие данные, затем загрузит \(candidate.name).") }
            }
        }
    }

    // Equal-sized touch targets with a clear visual hierarchy; avoid
    // a long list of indistinguishable text-only backup buttons.
    private func backupAction(_ title: String, subtitle: String, symbol: String,
                              tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 39, height: 39)
                    .background(tint.opacity(0.17), in: RoundedRectangle(cornerRadius: 13))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.74))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(13)
            .shiftlyGlassControl(radius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func summary(_ name: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(.white)
            Text(name).font(.caption2).foregroundStyle(Color.white.opacity(0.72))
        }.frame(maxWidth: .infinity)
    }

    private func emptyState(_ label: String) -> some View {
        Text(label).font(.subheadline).foregroundStyle(Color.white.opacity(0.76))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15).shiftlyGlass(radius: 18)
    }

    private func backupRow(_ file: URL, external: Bool) -> some View {
        HStack(spacing: 12) {
            Button { openBackup(at: file, withSecurityScope: external) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.green)
                        .frame(width: 25)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.lastPathComponent).font(.subheadline.bold())
                            .foregroundStyle(.white).lineLimit(2)
                        Text(metadata(file)).font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            .buttonStyle(.plain)
            if !external {
                ShareLink(item: file) { Image(systemName: "square.and.arrow.up")
                    .font(.subheadline).foregroundStyle(.white)
                    .frame(width: 34, height: 40)
                }
            }
        }
        .padding(13).shiftlyGlassControl(radius: 17)
    }

    private func metadata(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let date = values?.contentModificationDate.map(ruDate) ?? "Дата неизвестна"
        let size = ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
        return "\(date) · \(size)"
    }

    private func refreshFiles() {
        localFiles = AutomaticBackups.allFiles()
        if let folder = externalFolder {
            do {
                folderFiles = try FileManager.default.contentsOfDirectory(at: folder,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])
                    .filter { $0.pathExtension.lowercased() == "json" }
                    .sorted {
                        let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        return a > b
                    }
                info = "Найдено \(folderFiles.count) JSON-файлов в «\(folder.lastPathComponent)»."
            } catch {
                folderFiles = []
                info = "Нет доступа к папке: \(error.localizedDescription). Выбери папку снова или отдельный JSON."
            }
        }
        refreshed = Date()
    }

    private func releaseFolder() {
        if folderScopeActive { externalFolder?.stopAccessingSecurityScopedResource() }
        folderScopeActive = false
    }

    private func createLocalCopy() {
        do {
            manualCopy = try AutomaticBackups.createManual(store.data)
            refreshFiles()
            info = "Снимок создан. Чтобы не потерять его при переустановке, экспортируй в iCloud Drive."
        } catch { info = "Ошибка сохранения: \(error.localizedDescription)" }
    }

    private func openBackup(at url: URL, withSecurityScope: Bool) {
        let scope = withSecurityScope && url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            parseBackup(raw, name: url.lastPathComponent,
                        modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
        } catch {
            info = "Не удалось прочитать JSON: \(error.localizedDescription)"
        }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            info = "Буфер пустой. Открой JSON в «Файлах», скопируй содержимое и попробуй ещё раз."
            return
        }
        guard let raw = text.data(using: .utf8) else {
            info = "Не удалось прочитать текст из буфера"; return
        }
        parseBackup(raw, name: "Скопированный JSON", modified: nil)
    }

    private func parseBackup(_ raw: Data, name: String, modified: Date?) {
        guard !raw.isEmpty && raw.count < 40_000_000 else {
            info = "Файл пустой или слишком большой (до 40 МБ)"; return
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: raw)
            guard let root = obj as? [String: Any], root["sessions"] is [[String: Any]],
                  root["limitMinutes"] is NSNumber else {
                info = "Это не резервная копия Shiftly. Нет полей sessions и limitMinutes."; return
            }
            let decoded = try JSONDecoder().decode(ShiftData.self, from: raw)
            guard decoded.limitMinutes > 0 && decoded.limitMinutes <= 1440 &&
                    decoded.sessions.allSatisfy({ s in
                        s.breakLimitMinutes > 0 && (s.end == nil || s.end! > s.start) &&
                        s.breaks.allSatisfy { $0.start >= s.start && ($0.end == nil || $0.end! >= $0.start) }
                    }) else {
                info = "В копии обнаружены некорректные даты или лимиты"; return
            }
            preview = BackupPreview(name: name, data: decoded, bytes: raw.count, modified: modified)
            info = nil
        } catch { info = "Файл не похож на JSON-копию Shiftly: \(error.localizedDescription)" }
    }

    private func restore(_ candidate: BackupPreview) {
        guard AutomaticBackups.saveBeforeRestore(store.data) else {
            info = "Не удалось создать страховочную копию. Восстановление отменено."
            preview = nil
            return
        }
        store.replaceData(candidate.data)
        preview = nil
        refreshFiles()
        info = "Восстановлено \(candidate.data.sessions.count) смен и \(candidate.breaks) перекуров. Предыдущая история сохранена локально."
    }
}
