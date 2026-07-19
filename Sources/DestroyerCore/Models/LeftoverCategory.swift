import Foundation

/// Categoria di un file residuo lasciato da un'app dopo l'installazione/uso.
/// L'ordine dei case guida anche l'ordine di presentazione nella review.
public enum LeftoverCategory: String, CaseIterable, Codable, Sendable {
    case binary          // il bundle .app stesso
    case caches
    case preferences
    case appSupport
    case containers
    case groupContainers
    case logs
    case launchAgents
    case launchDaemons
    case privilegedHelper
    case savedState
    case applicationScripts
    case httpStorages
    case webKit
    case cookies
    case preferencePanes
    case quickLook
    case spotlight
    case services
    case screenSavers
    case internetPlugins

    /// Etichetta leggibile per la UI (in italiano, coerente con l'app).
    public var displayName: String {
        switch self {
        case .binary:             return "Applicazione"
        case .caches:             return "Cache"
        case .preferences:        return "Preferenze"
        case .appSupport:         return "Supporto applicazione"
        case .containers:         return "Container"
        case .groupContainers:    return "Group Container"
        case .logs:               return "Log"
        case .launchAgents:       return "Launch Agent"
        case .launchDaemons:      return "Launch Daemon (sistema)"
        case .privilegedHelper:   return "Helper privilegiato"
        case .savedState:         return "Stato salvato"
        case .applicationScripts: return "Script applicazione"
        case .httpStorages:       return "HTTP Storage"
        case .webKit:             return "WebKit"
        case .cookies:            return "Cookie"
        case .preferencePanes:    return "Pannello preferenze"
        case .quickLook:          return "Plugin QuickLook"
        case .spotlight:          return "Spotlight importer"
        case .services:           return "Servizio"
        case .screenSavers:       return "Screen Saver"
        case .internetPlugins:    return "Internet Plug-in"
        }
    }
}
