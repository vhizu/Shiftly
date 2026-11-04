import SwiftUI

@main
struct ShiftlyApp: App {
    @StateObject private var store = ShiftStore()
    var body: some Scene {
        WindowGroup {
            MainView().environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.67, green: 0.48, blue: 0.98))
        }
    }
}
