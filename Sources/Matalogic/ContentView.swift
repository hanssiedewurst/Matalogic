import SwiftUI

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
                    projects.append(SongProject(title: "New Song"))
                } label: {
                    Label("New Song", systemImage: "plus")
                }
            }
        } detail: {
            if let project = selectedProject {
                ProjectDashboard(project: project)
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
    }

    private var selectedProject: SongProject? {
        projects.first { $0.id == selection }
    }
}

private struct ProjectDashboard: View {
    let project: SongProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.largeTitle.bold())
                    Text(project.artist.isEmpty ? "No artist set" : project.artist)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    MetricCard(title: "Duration", value: format(project.duration))
                    MetricCard(title: "Tempo", value: project.bpm.map { "\(Int($0)) BPM" } ?? "—")
                    MetricCard(title: "Lyrics", value: "\(project.lyrics.count) lines")
                    MetricCard(title: "Shots", value: "\(project.shots.count)")
                }

                GroupBox("Workflow") {
                    HStack(spacing: 12) {
                        WorkflowButton("Import Logic", systemImage: "square.and.arrow.down")
                        WorkflowButton("Lyrics", systemImage: "text.quote")
                        WorkflowButton("References", systemImage: "photo.on.rectangle.angled")
                        WorkflowButton("Storyboard", systemImage: "rectangle.split.3x1")
                        WorkflowButton("Generate Video", systemImage: "sparkles.tv")
                    }
                    .padding(.vertical, 8)
                }

                GroupBox("Song markers") {
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

                GroupBox("Video pipeline") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference photos → storyboard → individual shots → review → final assembly")
                        Text("The renderer is provider-agnostic. v0.1 ships with a mock provider; Runway can be added without changing the project model.")
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
