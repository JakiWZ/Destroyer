import SwiftUI
import AppKit

/// Riceve le app trascinate sull'icona del Dock (o aperte con "Apri con Destroyer")
/// e le inoltra all'AppState per avviare subito la disinstallazione.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let appURL = urls.first(where: { $0.pathExtension == "app" }) else { return }
        Task { @MainActor in
            AppState.shared?.openDroppedApp(at: appURL)
        }
    }
}

@main
struct DestroyerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.titleBar)

        MenuBarExtra("Destroyer", systemImage: "bolt.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
