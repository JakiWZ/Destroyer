import SwiftUI

struct SpaceView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                spaceLens
                filesSection
                photosSection
                languagesSection
                fatSection
                if selectedBytes > 0 { footer }
            }
            .padding(28)
        }
        .techGridBackground()
        .onAppear { if appState.spaceEntries.isEmpty && !appState.isScanningLens { appState.scanSpaceLens() } }
    }

    /// Intestazione di una sezione on-demand: pulsante "Analizza" o spinner.
    @ViewBuilder
    private func analyzeGate(tag: String, scanning: Bool, done: Bool, empty: Bool, action: @escaping () -> Void) -> some View {
        if scanning {
            HStack(spacing: 8) { TechTag(text: tag); ProgressView().controlSize(.small); Text("Analisi…").font(.caption).foregroundStyle(Theme.textSecondary) }
        } else if !done && empty {
            HStack { TechTag(text: tag); Spacer(); GhostButton(title: "Analizza", systemImage: "magnifyingglass", action: action) }
        } else if done && empty {
            HStack { TechTag(text: tag); Spacer(); Text("nessun risultato").font(Theme.mono(9)).foregroundStyle(Theme.textTertiary) }
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        analyzeGate(tag: "large, old & duplicates", scanning: appState.isScanningFiles,
                    done: appState.didScanFiles, empty: appState.largeOldFiles.isEmpty && appState.duplicateGroups.isEmpty) {
            appState.scanFilesInsight()
        }
        largeOld
        duplicates
    }

    @ViewBuilder
    private var photosSection: some View {
        analyzeGate(tag: "similar photos", scanning: appState.isScanningPhotos,
                    done: !appState.photoGroups.isEmpty || appState.isScanningPhotos, empty: appState.photoGroups.isEmpty) {
            appState.scanPhotos()
        }
        similarPhotos
    }

    @ViewBuilder
    private var languagesSection: some View {
        analyzeGate(tag: "language files", scanning: appState.isScanningLangs,
                    done: appState.didScanLangs, empty: appState.languageFiles.isEmpty) {
            appState.scanLanguages()
        }
        languageFiles
    }

    @ViewBuilder
    private var fatSection: some View {
        analyzeGate(tag: "universal binaries", scanning: false,
                    done: !appState.fatBinaries.isEmpty, empty: appState.fatBinaries.isEmpty) {
            appState.scanFatBinaries()
        }
        universalBinaries
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TechTag(text: "disk analyzer")
            Text("Spazio").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Mappa del disco, file grandi o vecchi e duplicati nella tua cartella utente.")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Space Lens (barre proporzionali, navigabile)
    private var spaceLens: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { appState.spaceUp() } label: {
                    Label("Indietro", systemImage: "chevron.left")
                        .font(Theme.mono(11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(appState.canSpaceGoUp ? Theme.surface : Theme.surface.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(appState.canSpaceGoUp ? Theme.accentSolid : Theme.textTertiary)
                .disabled(!appState.canSpaceGoUp)
                .help("Torna alla cartella superiore")

                TechTag(text: "space lens")
                Spacer()
            }
            breadcrumb
            SpaceTreemap(entries: appState.spaceEntries) { appState.drillInto($0) }
            let total = max(1, appState.spaceEntries.reduce(0) { $0 + $1.sizeBytes })
            ForEach(appState.spaceEntries.prefix(12)) { e in
                Button { appState.drillInto(e) } label: {
                    VStack(spacing: 3) {
                        HStack {
                            Image(systemName: e.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 10)).foregroundStyle(Theme.accentSolid)
                            Text(e.name).font(Theme.mono(12)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            Text(ByteSize.string(e.sizeBytes)).font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
                            if e.isDirectory { Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Theme.textTertiary) }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.strokeStrong)
                                Capsule().fill(Theme.accentGradient)
                                    .frame(width: max(3, geo.size.width * CGFloat(Double(e.sizeBytes) / Double(total))))
                            }
                        }.frame(height: 5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!e.isDirectory)
            }
        }
        .card(padding: 16)
    }

    /// Percorso corrente come testo semplice su una riga.
    /// NB: NON usare qui un breadcrumb a segmenti cliccabili (HStack/ForEach/Button)
    /// né testo composito: dentro la ScrollView verticale scatena un loop di layout
    /// infinito (ScrollView↔FlexFrame↔Stack) che blocca l'app. La navigazione
    /// "indietro" è affidata al pulsante Indietro qui sopra.
    private var breadcrumb: some View {
        Text(appState.spaceRoot.path)
            .font(Theme.mono(9))
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
    }

    // MARK: - File di lingua
    private var languageFiles: some View {
        Group {
            if !appState.languageFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TechTag(text: "language files")
                        Spacer()
                        Text("delicato").font(Theme.mono(8, weight: .bold)).foregroundStyle(Theme.warning)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(Theme.warning.opacity(0.15)))
                    }
                    Text("Rimuovere le lingue inutilizzate può invalidare la firma di un'app (reversibile dal Cestino).")
                        .font(.caption2).foregroundStyle(Theme.textTertiary)
                    VStack(spacing: 0) {
                        ForEach(appState.languageFiles.prefix(15)) { f in
                            fileRow(selected: f.isSelected, name: "\(f.appName) · \(f.language)",
                                    detail: f.url.path, size: f.sizeBytes) { appState.toggleLanguage(f) }
                        }
                    }.card(padding: 4)
                }
            }
        }
    }

    // MARK: - File grandi/vecchi (l'header/analizza è gestito dal gate)
    @ViewBuilder
    private var largeOld: some View {
        if !appState.largeOldFiles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TechTag(text: "large & old files")
                VStack(spacing: 0) {
                    ForEach(appState.largeOldFiles.prefix(20)) { f in
                        fileRow(selected: f.isSelected, name: f.url.lastPathComponent,
                                detail: f.url.deletingLastPathComponent().path, size: f.sizeBytes) {
                            appState.toggleLargeOld(f)
                        }
                    }
                }.card(padding: 4)
            }
        }
    }

    // MARK: - Duplicati
    @ViewBuilder
    private var duplicates: some View {
        if !appState.duplicateGroups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TechTag(text: "duplicates")
                ForEach(appState.duplicateGroups.prefix(15)) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(g.files.count)× \(ByteSize.string(g.sizeBytes))")
                                .font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.accentSolid)
                            Spacer()
                            Text("recuperabili \(ByteSize.string(g.reclaimableBytes))")
                                .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                        }
                        VStack(spacing: 0) {
                            ForEach(g.files) { f in
                                fileRow(selected: f.isSelected, name: f.url.lastPathComponent,
                                        detail: f.url.deletingLastPathComponent().path, size: f.sizeBytes) {
                                    appState.toggleDuplicate(groupID: g.id, fileID: f.id)
                                }
                            }
                        }.card(padding: 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var similarPhotos: some View {
        if !appState.photoGroups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TechTag(text: "similar photos")
                ForEach(appState.photoGroups.prefix(10)) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(g.photos.count) simili · recuperabili \(ByteSize.string(g.reclaimableBytes))")
                            .font(Theme.mono(10)).foregroundStyle(Theme.accentSolid)
                        VStack(spacing: 0) {
                            ForEach(g.photos) { p in
                                fileRow(selected: p.isSelected, name: p.url.lastPathComponent,
                                        detail: p.url.deletingLastPathComponent().path, size: p.sizeBytes) {
                                    appState.togglePhoto(groupID: g.id, fileID: p.id)
                                }
                            }
                        }.card(padding: 4)
                    }
                }
                if appState.photoGroups.contains(where: { $0.photos.contains(where: \.isSelected) }) {
                    HStack {
                        Spacer()
                        AccentButton(title: "Rimuovi foto selezionate", systemImage: "trash") { appState.trashSelectedPhotos() }
                    }
                }
            }
        }
    }

    @State private var confirmThin = false
    @ViewBuilder
    private var universalBinaries: some View {
        if !appState.fatBinaries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TechTag(text: "universal binaries")
                    Spacer()
                    Text("irreversibile").font(Theme.mono(8, weight: .bold)).foregroundStyle(Theme.danger)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(Theme.danger.opacity(0.15)))
                }
                Text("Rimuove l'architettura non nativa dalle app. NON reversibile e invalida la firma: l'app potrebbe non avviarsi.")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
                VStack(spacing: 0) {
                    ForEach(appState.fatBinaries.prefix(15)) { b in
                        HStack(spacing: 10) {
                            Button { appState.toggleFat(b) } label: {
                                Image(systemName: b.isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(b.isSelected ? Theme.danger : Theme.textTertiary)
                            }.buttonStyle(.plain)
                            Text(b.appName).font(.system(size: 12)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Text(b.archs.joined(separator: "+")).font(Theme.mono(8)).foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text(ByteSize.string(b.sizeBytes)).font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }.card(padding: 4)
                if appState.fatBinaries.contains(where: \.isSelected) {
                    HStack {
                        Spacer()
                        Button(role: .destructive) { confirmThin = true } label: {
                            Label("Assottiglia (irreversibile)", systemImage: "exclamationmark.triangle")
                        }.foregroundStyle(Theme.danger)
                    }
                    .confirmationDialog("Assottigliare i binari selezionati?", isPresented: $confirmThin, titleVisibility: .visible) {
                        Button("Assottiglia (irreversibile)", role: .destructive) { appState.thinSelectedFat() }
                        Button("Annulla", role: .cancel) {}
                    } message: {
                        Text("Operazione permanente. Invalida la firma delle app: alcune potrebbero non avviarsi più. Consigliato solo se sai cosa stai facendo.")
                    }
                }
            }
        }
    }

    private func fileRow(selected: Bool, name: String, detail: String, size: Int64, toggle: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Theme.accentSolid : Theme.textTertiary)
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 12)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(detail).font(Theme.mono(9)).foregroundStyle(Theme.textTertiary).lineLimit(1)
            }
            Spacer()
            Text(ByteSize.string(size)).font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var selectedBytes: Int64 {
        let large: Int64 = appState.largeOldFiles.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
        let dupes: Int64 = appState.duplicateGroups.flatMap { $0.files }.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
        let langs: Int64 = appState.languageFiles.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
        return large + dupes + langs
    }

    private var footer: some View {
        HStack {
            Text("\(ByteSize.string(selectedBytes)) selezionati").font(Theme.mono(12, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Spacer()
            AccentButton(title: "Sposta nel Cestino", systemImage: "trash") { appState.trashSelectedFiles() }
        }
        .padding(.top, 4)
    }
}
