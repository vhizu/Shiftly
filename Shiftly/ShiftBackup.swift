import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ShiftBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }
    var data: ShiftData
    init(data: ShiftData = ShiftData()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = try JSONDecoder().decode(ShiftData.self, from: configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(data))
    }
}
struct ShiftCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(data: ShiftData) {
        func cell(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let iso = ISO8601DateFormatter()
        var lines = ["type,start,end,stream,category,details,minutes"]
        for s in data.sessions { lines.append(["shift",iso.string(from:s.start),s.end.map(iso.string(from:)) ?? "","","","",""].map(cell).joined(separator:",")) }
        for n in data.notes ?? [] { lines.append(["note",iso.string(from:n.date),"",n.stream,n.category,n.details,String(n.durationMinutes)].map(cell).joined(separator:",")) }
        text = lines.joined(separator:"\n")
    }
    init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
