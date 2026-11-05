import SwiftUI

@main
struct ShiftlyApp: App {
    @StateObject private var store = ShiftStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(store)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.74, green: 0.50, blue: 0.99))
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("shiftly.widgetStart"))) { _ in store.synchronize() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.synchronize(); ShiftReminders.schedule(store: store) }
                    else if phase == .background { store.persistNow() }
                }
        }
    }
}
