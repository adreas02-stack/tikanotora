import SwiftUI

@main
struct TiKanoToraApp: App {
    @StateObject private var store = LogStore.shared

    init() {
        NotificationManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await NotificationManager.shared.requestAndSchedule()
                    await store.syncPending()
                }
        }
    }
}
