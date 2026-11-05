import Foundation

enum AutomaticBackups {
    private static var directory: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let folder = documents.appendingPathComponent("ShiftlyBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    static func latestFile() -> URL? {
        guard let url = directory?.appendingPathComponent("Shiftly-latest.json"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    static func snapshots() -> [URL] {
        guard let folder = directory,
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return urls.filter { $0.lastPathComponent.hasPrefix("Shiftly-auto-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    // Explicit snapshots are never silently pruned along with automatic ones.
    // Save a copy suitable for sharing to Files/iCloud Drive.
    static func createManual(_ data: ShiftData) throws -> URL {
        guard let folder = directory else {
            throw NSError(domain: "Shiftly.Backups", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Папка резервных копий недоступна"])
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let file = "Shiftly-manual-\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(6)).json"
        let url = folder.appendingPathComponent(file)
        try JSONEncoder().encode(data).write(to: url, options: .atomic)
        return url
    }

    static func allFiles() -> [URL] {
        guard let folder = directory,
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return urls.filter {
            $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.hasPrefix("Shiftly-")
        }.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return a > b
        }
    }

    // Always preserve the previous history before an intentional import.
    // Unlike periodic snapshots, this one must never be skipped by throttling.
    @discardableResult
    static func saveBeforeRestore(_ data: ShiftData) -> Bool {
        guard let folder = directory, let encoded = try? JSONEncoder().encode(data) else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let filename = "Shiftly-auto-\(stamp)-before-restore-\(UUID().uuidString.prefix(8)).json"
        let url = folder.appendingPathComponent(filename)
        do {
            try encoded.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func save(_ data: ShiftData) {
        guard let folder = directory, let encoded = try? JSONEncoder().encode(data) else { return }
        // Last local copy is updated after every state change.
        try? encoded.write(to: folder.appendingPathComponent("Shiftly-latest.json"), options: .atomic)
        let now = Date()
        let recent = snapshots().first.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        guard recent == nil || now.timeIntervalSince(recent!) >= 15 * 60 else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = folder.appendingPathComponent("Shiftly-auto-\(formatter.string(from: now)).json")
        try? encoded.write(to: url, options: .atomic)
        for old in snapshots().dropFirst(20) { try? FileManager.default.removeItem(at: old) }
    }
}
