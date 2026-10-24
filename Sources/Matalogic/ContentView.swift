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
            lyrics: [
                LyricLine(text: "Import lyrics from TXT, LRC or SRT")
            ],
            references: [],
            shots: [
                VideoShot(start: 0, duration: 5, prompt: "Opening establishing shot")
            ]
        )
    ]

    @State private var selection: SongProject.ID?
    @State private var showLogicImporter = false
    @State private var showLyricsImporter = false
    @State private var showMatamike = false
    @State private var importError: String?

    private let logicImporter = LogicImportService()
    private let lyricsImporter = LyricsImportService()

    var body: some View {
        NavigationSplitView {
            List(projects, selection: $selection) { project in
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                    Text(project.artist.isEmpty ? "Unknown artist" : project.artist)
                        .foregroundStyle(.secondary)
                }
                .tag(project.id)
            }
            .navigationTitle("Matalogic")
            .toolbar {
                Button {
                    let project = SongProject(title: "New Song")
                    projects.append(project)
                    selection = project.id
                } label: {
                    Label("New Song", systemImage: "plus")
                }
            }
        } detail: {
            if let index = selectedProjectIndex {
                ProjectDashboard(
                    project: $projects[index],
                    onImportLogic: { showLogicImporter = true },
                    onImportLyrics: { showLyricsImporter = true },
                    onAskMatamike: { showMatamike = true }
                )
            } else {
                ContentUnavailableView(
                    "Select a song",
                    systemImage: "music.note.list",
                    description: Text("Import a Logic exchange package or create a new project.")
                )
            }
        }
        .frame(minWidth: 980, minHeight: 640)
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
        .sheet(isPresented: $showMatamike) {
            MatamikeChatView(project: selectedProject)
        }
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private var selectedProjectIndex: Int? {
        projects.firstIndex { $0.id == selection }
    }

    private var selectedProject: SongProject? {
        guard let index = selectedProjectIndex else { return nil }
        return projects[index]
    }

    private func importLogicPackage(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { importError = error.localizedDescription }
            return
        }
        let selectedID = selection
        let scoped = url.startAccessingSecurityScopedResource()

        Task {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let package = try logicImporter.discoverPackage(at: url)
                let imported = try await logicImporter.importProject(from: package)
                if let index = projects.firstIndex(where: { $0.id == selectedID }) {
                    var replacement = imported
                    replacement.artist = projects[index].artist
                    projects[index] = replacement
                    selection = replacement.id
                } else {
                    projects.append(imported)
                    selection = imported.id
                }
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
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct ProjectDashboard: View {
    @Binding var project: SongProject
    let onImportLogic: () -> Void
    let onImportLyrics: () -> Void
    let onAskMatamike: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.title)
                            .font(.largeTitle.bold())
                        Text(project.artist.isEmpty ? "No artist set" : project.artist)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onAskMatamike) {
                        HStack(spacing: 8) {
                            MatamikeAvatar(size: 34)
                            Text("Ask Matamike")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    MetricCard(title: "Duration", value: format(project.duration))
                    MetricCard(title: "Tempo", value: project.bpm.map { "\(Int($0.rounded())) BPM" } ?? "—")
                    MetricCard(title: "Lyrics", value: "\(project.lyrics.count) lines")
                    MetricCard(title: "Stems", value: "\(project.stemURLs.count)")
                }

                GroupBox("Audio") {
                    VStack(alignment: .leading, spacing: 10) {
                        if project.waveform.isEmpty {
                            ContentUnavailableView(
                                "No waveform yet",
                                systemImage: "waveform",
                                description: Text("Import a Logic exchange folder with a WAV, AIFF, M4A or CAF master.")
                            )
                            .frame(height: 120)
                        } else {
                            WaveformView(samples: project.waveform)
                                .frame(height: 120)
                        }

                        if let master = project.masterAudioURL {
                            Label(master.lastPathComponent, systemImage: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Workflow") {
                    HStack(spacing: 12) {
                        Button(action: onImportLogic) {
                            Label("Import Logic", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onImportLyrics) {
                            Label("Lyrics", systemImage: "text.quote")
                        }
                        .buttonStyle(.bordered)

                        WorkflowButton("References", systemImage: "photo.on.rectangle.angled")
                        WorkflowButton("Storyboard", systemImage: "rectangle.split.3x1")
                        WorkflowButton("Generate Video", systemImage: "sparkles.tv")
                    }
                    .padding(.vertical, 8)
                }

                GroupBox("Song markers") {
                    if project.markers.isEmpty {
                        Text("No MIDI markers imported yet.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(project.markers) { marker in
                                HStack {
                                    Text(format(marker.time))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 70, alignment: .leading)
                                    Text(marker.name)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                GroupBox("Video pipeline") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference photos → storyboard → individual shots → review → final assembly")
                        Text("The renderer stays provider-agnostic. Matamike can later use the same project context to help write prompts, plan shots and diagnose missing assets.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(28)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct WaveformView: View {
    let samples: [Float]

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let width = size.width / CGFloat(samples.count)
            let middle = size.height / 2

            for (index, sample) in samples.enumerated() {
                let amplitude = max(1, CGFloat(sample) * middle)
                let x = CGFloat(index) * width
                var path = Path()
                path.move(to: CGPoint(x: x, y: middle - amplitude))
                path.addLine(to: CGPoint(x: x, y: middle + amplitude))
                context.stroke(path, with: .foreground, lineWidth: max(1, width * 0.7))
            }
        }
        .padding(.vertical, 8)
        .accessibilityLabel("Audio waveform")
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WorkflowButton: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Button(action: {}) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
    }
}
