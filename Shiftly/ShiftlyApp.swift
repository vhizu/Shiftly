import SwiftUI

@main
struct ShiftlyApp: App {
    @StateObject private var store = ShiftStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.67, green: 0.48, blue: 0.98))
                .onChange(of: scenePhase) { _, phase in if phase == .active { store.synchronize(); ShiftReminders.schedule(store: store) } }
        }
    }
}
