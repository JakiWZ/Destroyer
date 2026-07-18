import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Rileva se un'app è in esecuzione e la chiude prima della disinstallazione.
public struct AppProcess {

    public init() {}

    /// Vero se esiste almeno un'istanza in esecuzione con questo bundle identifier.
    public func isRunning(bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier else { return false }
        #if canImport(AppKit)
        return !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
        #else
        return false
        #endif
    }

    /// Chiude tutte le istanze dell'app. Ritorna true se al termine non risulta più attiva.
    /// Prova prima la chiusura gentile, poi (se necessario) forza.
    @discardableResult
    public func quit(bundleIdentifier: String?) -> Bool {
        guard let id = bundleIdentifier else { return true }
        #if canImport(AppKit)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: id)
        guard !apps.isEmpty else { return true }
        for app in apps { app.terminate() }
        // Attesa breve per la chiusura gentile.
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        // Ancora attiva: forza.
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) {
            app.forceTerminate()
        }
        Thread.sleep(forTimeInterval: 0.5)
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
        #else
        return true
        #endif
    }
}
