import SwiftUI

@main
struct RCONCommanderApp: App {
    @StateObject private var store = ServerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ServerListView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { RCONSession.shared.disconnect() }
                }
        }
    }
}
