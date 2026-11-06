import SwiftUI

// Shiftly 1.11 / stage 1: one static high-quality sprite per app state.
// No layered eye / hair rigging and no additional background image inside PNG.
enum MascotScene: Equatable {
    case work, coffee, lunch, night, off, success

    var assetName: String {
        switch self {
        case .work, .night: return "Mascot11Work" // Night cutout needs cleanup first.
        case .coffee: return "Mascot11Coffee"
        case .lunch: return "Mascot11Lunch"
        case .off: return "Mascot11Off"
        case .success: return "Mascot11Success"
        }
    }

    static func home(session: WorkSession?, active: BreakSession?,
                     recentFinished: WorkSession?, now: Date) -> MascotScene {
        if let active { return active.type == .lunch ? .lunch : .coffee }
        if let session {
            return Calendar.current.component(.hour, from: session.start) >= 14 ? .night : .work
        }
        if let recentFinished, let end = recentFinished.end,
           now.timeIntervalSince(end) >= 0, now.timeIntervalSince(end) < 3 * 3600 {
            return .success
        }
        return .off
    }
}
