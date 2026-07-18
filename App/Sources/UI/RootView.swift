import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .overlay {
            if !appState.hasFullDiskAccess {
                FullDiskAccessGate()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasFullDiskAccess)
        .overlay(alignment: .bottom) {
            if let app = appState.trashedAppSuggestion {
                trashSuggestionToast(app)
            }
        }
        .overlay(alignment: .top) {
            if let alert = appState.realtimeAlert {
                realtimeAlertToast(alert)
            }
        }
        .animation(.spring(duration: 0.35), value: appState.trashedAppSuggestion)
        .animation(.spring(duration: 0.35), value: appState.realtimeAlert?.id)
        .onAppear {
            appState.recheckAccess()
            appState.refreshStatus()
            appState.loadInstalledApps()
            appState.startTrashWatcher()
            appState.checkForUpdates()
            appState.restoreRealtime()
            appState.restoreSchedule()
            appState.handleLaunchArguments()
        }
    }

    private func realtimeAlertToast(_ f: ThreatFinding) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 22)).foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 1) {
                Text("Protezione in tempo reale: elemento sospetto")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(f.family ?? f.itemURL.lastPathComponent)
                    .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer()
            AccentButton(title: "Esamina", systemImage: "shield") {
                appState.findings = [f]
                appState.didScanThreats = true
                appState.section = .protection
                appState.dismissRealtimeAlert()
            }
            GhostButton(title: "Ignora") { appState.dismissRealtimeAlert() }
        }
        .padding(14)
        .frame(maxWidth: 560)
        .background(RoundedRectangle(cornerRadius: Theme.corner).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Theme.danger.opacity(0.5)))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.top, 16)
    }

    private func trashSuggestionToast(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(app.name) è nel Cestino")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Vuoi rimuovere anche i file residui?")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            AccentButton(title: "Pulisci residui", systemImage: "sparkles") {
                appState.cleanupTrashedApp()
            }
            GhostButton(title: "No") { appState.dismissTrashedSuggestion() }
        }
        .padding(14)
        .frame(maxWidth: 520)
        .background(RoundedRectangle(cornerRadius: Theme.corner).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Theme.strokeStrong))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(24)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            logo
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .padding(.bottom, 14)

            ForEach(AppSection.allCases) { section in
                SidebarItem(
                    icon: section.systemImage,
                    title: section.title,
                    isSelected: appState.section == section,
                    isAvailable: section.isAvailable
                ) {
                    if section.isAvailable { appState.section = section }
                }
            }
            Spacer()
            footer
                .padding(12)
        }
        .padding(.horizontal, 8)
        .frame(width: 224)
        .background(Theme.backgroundDeep)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.stroke).frame(width: 1)
        }
    }

    private var logo: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accentGradient)
                    .frame(width: 34, height: 34)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Destroyer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Mac utility")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let update = appState.updateResult, update.isNewer {
            Button {
                NSWorkspace.shared.open(update.releaseURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.accentSolid)
                    Text("Aggiornamento \(update.latestVersion)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aggiornamento disponibile: versione \(update.latestVersion)")
        } else {
            HStack(spacing: 6) {
                Circle().fill(Theme.ok).frame(width: 7, height: 7)
                Text("Sistema pronto v\(AppState.appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement()
            .accessibilityLabel("Sistema pronto, versione \(AppState.appVersion)")
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        Group {
            switch appState.section {
            case .dashboard:    DashboardView()
            case .applications: UninstallerView()
            case .cleanup:      CleanupView()
            case .space:        SpaceView()
            case .performance:  PerformanceView()
            case .privacy:      PrivacyView()
            case .monitor:      MonitorView()
            case .protection:   ProtectionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

struct ComingSoonView: View {
    let section: AppSection
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: section.systemImage)
                .font(.system(size: 46))
                .foregroundStyle(Theme.accentGradient)
            Text("\(section.title) — in arrivo")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Questo modulo fa parte della roadmap successiva all'MVP.")
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
