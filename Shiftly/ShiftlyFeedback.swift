import UIKit
import Foundation

// Lightweight, user-controllable haptics. System accessibility and silent
// hardware limitations are always respected by UIKit feedback generators.
enum ShiftlyFeedback {
    private static var enabled: Bool {
        (UserDefaults.standard.object(forKey: "shiftly.haptics") as? Bool) ?? true
    }
    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
