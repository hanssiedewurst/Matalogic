import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var projects: [SongProject] = [
        SongProject(
            title: "Demo Song",
            artist: "Matalogic",
            duration: 222,
            bpm: 116,
            markers: [
                SongMarker(name: "Intro", time: 0),
                SongMarker(name: "Verse 1", time: 18),
                SongMarker(name: "Chorus", time: 57)
            ],
            lyrics: [LyricLine(text: "Import lyrics from TXT, LRC or SRT")],
            shots: [VideoShot(start: 0, duration: 5, prompt: "Opening establishing shot")]
        )
    ]

    @State private var selection: SongProject.ID?
    @State private var section: WorkspaceSection = .overview
    @State private var showLogicImporter = false
    @State private var showLyricsImporter = false
    @State private var showExchange = false
    @State private var importError: String?
    @State private var liveEntries: [LiveSetEntry] = []
    @StateObject private var renderQueue = RenderQueueModel()
    @StateObject private var sharedWorkspace = SharedWorkspaceModel()

    private let logicImporter = LogicImportService()
    private let lyricsImporter = LyricsImportService()

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                projects: projects,
                selection: $selection,
                section: $section,
                encoreCount: liveEntries.filter(\.isEncore).count,
                onOpenExchange: { showExchange = true },
                onNewProject: addProject
            )
            .frame(width: 245)

            Divider()

            workspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            MatamikeChatView(
                project: selectedProject,
                availableProjects: projects,
                compact: true,
                onAction: handleMatamikeAction
            )
            .frame(width: 340)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
        .frame(minWidth: 1260, minHeight: 720)
        .onAppear {
            selection = selection ?? projects.first?.id
        }
        .fileImporter(
            isPresented: $showLogicImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: importLogicPackage
        )
        .fileImporter(
            isPresented: $showLyricsImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: importLyrics
        )
        .sheet(isPresented: $showExchange) {
            SharedWorkspaceView(model: sharedWorkspace) { url in
                importLogicFolder(url, replaceSelected: false)
                showExchange = false
            }
            .frame(minWidth: 940, minHeight: 650)
        }
        .alert(
            "Import fehlgeschlagen",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unbekannter Fehler")
        }
    }

    @ViewBuilder
    private var workspace: some View {
        switch section {
        case .overview:
            OverviewView(
                projects: projects,
                selection: $selection,
                onImportLogic: { showLogicImporter = true },
                onImportLyrics: { showLyricsImporter = true },
                onOpenReferences: { section = .references },
                onOpenStoryboard: { section = .storyboard }
            )

        case .song:
            withSelectedProject { project in
                SongDetailView(
                    project: project,
                    onImportLogic: { showLogicImporter = true },
                    onImportLyrics: { showLyricsImporter = true }
                )
            }

        case .references:
            withSelectedProject { project in
                ReferenceLibraryView(project: project)
            }

        case .storyboard:
            withSelectedProject { project in
                StoryboardView(project: project, renderQueue: renderQueue)
            }

        case .renderQueue:
            RenderQueueView(model: renderQueue, projects: projects)

        case .live:
            LiveModeView(projects: projects, entries: $liveEntries)
        }
    }

    @ViewBuilder
    private func withSelectedProject<Content: View>(
        @ViewBuilder content: (Binding<SongProject>) -> Content
    ) -> some View {
        if let index = selectedProjectIndex {
            content($projects[index])
        } else {
            CompatUnavailableView(
                title: "Kein Song ausgewählt",
                systemImage: "music.note.list",
                description: "Wähle links ein Projekt aus oder importiere einen Logic-Song."
            )
        }
    }

    private var selectedProjectIndex: Int? {
        projects.firstIndex { $0.id == selection }
    }

    private var selectedProject: SongProject? {
        guard let index = selectedProjectIndex else { return nil }
        return projects[index]
    }

    private func addProject() {
        let project = SongProject(title: "Neuer Song")
        projects.append(project)
        selection = project.id
        section = .song
    }

    private func handleMatamikeAction(_ action: MatamikeAction) {
        switch action {
        case .addEncore(let projectID, let title):
            guard !liveEntries.contains(where: { $0.projectID == projectID && $0.isEncore }) else { return }
            liveEntries.append(LiveSetEntry(projectID: projectID, title: title, isEncore: true))
        }
    }

    private func importLogicPackage(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { importError = error.localizedDescription }
            return
        }
        importLogicFolder(url, replaceSelected: true)
    }

    private func importLogicFolder(_ url: URL, replaceSelected: Bool) {
        let selectedID = replaceSelected ? selection : nil
        let scoped = url.startAccessingSecurityScopedResource()

        Task {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let package = try logicImporter.discoverPackage(at: url)
                let imported = try await logicImporter.importProject(from: package)

                if let selectedID,
                   let index = projects.firstIndex(where: { $0.id == selectedID }) {
                    let existing = projects[index]
                    projects[index] = SongProject(
                        id: existing.id,
                        title: imported.title,
                        artist: existing.artist,
                        duration: imported.duration,
                        bpm: imported.bpm,
                        markers: imported.markers,
                        lyrics: imported.lyrics.isEmpty ? existing.lyrics : imported.lyrics,
                        references: imported.references.isEmpty ? existing.references : imported.references,
                        shots: existing.shots,
                        masterAudioURL: imported.masterAudioURL,
                        stemURLs: imported.stemURLs,
                        trackAssets: imported.trackAssets,
                        midiURL: imported.midiURL,
                        aafURL: imported.aafURL,
                        sourceFolderURL: imported.sourceFolderURL,
                        waveform: imported.waveform
                    )
                    selection = existing.id
                } else {
                    projects.append(imported)
                    selection = imported.id
                }
                section = .song
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func importLyrics(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { importError = error.localizedDescription }
            return
        }
        guard let index = selectedProjectIndex else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            projects[index].lyrics = try lyricsImporter.parse(url: url)
            section = .song
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct AppSidebar: View {
    let projects: [SongProject]
    @Binding var selection: SongProject.ID?
    @Binding var section: WorkspaceSection
    let encoreCount: Int
    let onOpenExchange: () -> Void
    let onNewProject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Matalogic").font(.title2.bold())
                    Text("Music · Video · Live").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(WorkspaceSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack {
                        Image(systemName: item.systemImage).frame(width: 22)
                        Text(item.label)
                        Spacer()
                        if item == .live && encoreCount > 0 {
                            Text("\(encoreCount)")
                                .font(.caption.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(section == item ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Button(action: onOpenExchange) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.square").frame(width: 22)
                    Text("Austausch")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            Divider().padding(.horizontal, 12)

            Text("PROJEKTE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(projects) { project in
                        Button {
                            selection = project.id
                            section = .song
                        } label: {
                            HStack {
                                Image(systemName: project.vocalTracks.isEmpty ? "music.note" : "music.mic")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title).lineLimit(1)
                                    if project.duration > 0 {
                                        Text(format(project.duration))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selection == project.id ? Color.secondary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 8)

            Button(action: onNewProject) {
                Label("Neues Projekt", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
