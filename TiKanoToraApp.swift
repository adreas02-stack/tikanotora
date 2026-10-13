import SwiftUI

@main
struct TiKanoToraApp: App {
    @StateObject private var store = LogStore.shared
    @StateObject private var categoryStore = CategoryStore.shared
    @StateObject private var quickLog = QuickLog.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(categoryStore)
                .environmentObject(quickLog)
                .task {
                    await NotificationManager.shared.requestAndSchedule()
                    store.backfillGaps()
                }
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                NotificationManager.shared.resumeIfSnoozeExpired()
                store.backfillGaps()
            }
        }
    }
}
