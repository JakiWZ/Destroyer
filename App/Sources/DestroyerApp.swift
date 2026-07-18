import SwiftUI

@main
struct DestroyerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}
