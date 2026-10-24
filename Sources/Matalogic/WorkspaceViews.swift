import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case song
    case references
    case storyboard
    case renderQueue
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Übersicht"
        case .song: return "Song"
        case .references: return "Referenzen"
        case .storyboard: return "Storyboard"
        case .renderQueue: return "Render Queue"
        case .live: return "Live Mode"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "house"
        case .song: return "music.note"
        case .references: return "photo.on.rectangle.angled"
        case .storyboard: return "rectangle.split.3x1"
        case .renderQueue: return "list.bullet.rectangle"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

struct OverviewView: View {
    let projects: [SongProject]
    @Binding var selection: SongProject.ID?
    let onImportLogic: () -> Void
    let onImportLyrics: () -> Void
    let onOpenReferences: () -> Void
    let onOpenStoryboard: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Willkommen bei")
                        .font(.title2.bold())
                    Text("Matalogic")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Songs, Lyrics, KI-Videos und Live-Workflow rund um Logic Pro.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    ActionCard(
                        title: "Song aus Logic importieren",
                        subtitle: "Audio, Marker, Tempo und Stems",
                        systemImage: "square.and.arrow.down",
                        prominent: true,
                        action: onImportLogic
                    )
                    ActionCard(
                        title: "Lyrics hinzufügen",
                        subtitle: "TXT, LRC oder SRT",
                        systemImage: "text.quote",
                        action: onImportLyrics
                    )
                    ActionCard(
                        title: "Referenzbilder",
                        subtitle: "Personen, Outfits, Locations",
                        systemImage: "photo.on.rectangle.angled",
                        action: onOpenReferences
                    )
                    ActionCard(
                        title: "Musikvideo erstellen",
                        subtitle: "Storyboard und KI-Shots",
                        systemImage: "sparkles.tv",
                        action: onOpenStoryboard
                    )
                }

                GroupBox("Projekte") {
                    VStack(spacing: 0) {
                        if projects.isEmpty {
                            ContentUnavailableView(
                                "Noch keine Songs",
                                systemImage: "music.note.list",
                                description: Text("Importiere einen Logic-Export oder lege einen Song an.")
                            )
                            .frame(height: 220)
                        } else {
                            ForEach(projects) { project in
                                Button {
                                    selection = project.id
                                } label: {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor.opacity(0.18))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "waveform").foregroundStyle(Color.accentColor))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(project.title).font(.headline)
                                            Text(project.artist.isEmpty ? "Unbekannter Artist" : project.artist)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                        Text(format(project.duration)).monospacedDigit().foregroundStyle(.secondary)
                                        Text(project.bpm.map { "\(Int($0.rounded())) BPM" } ?? "—")
                                            .frame(width: 72)
                                            .foregroundStyle(.secondary)
                                        StatusPill(text: projectStatus(project))
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if project.id != projects.last?.id { Divider() }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                WorkflowStrip()
            }
            .padding(28)
        }
    }

    private func projectStatus(_ project: SongProject) -> String {
        if project.masterAudioURL == nil { return "Audio fehlt" }
        if project.lyrics.isEmpty { return "Lyrics fehlen" }
        if project.references.isEmpty { return "Referenzen" }
        if project.shots.isEmpty { return "Storyboard" }
        if project.shots.contains(where: { $0.status != .approved }) { return "In Arbeit" }
        return "Fertig"
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct SongDetailView: View {
    @Binding var project: SongProject
    let onImportLogic: () -> Void
    let onImportLyrics: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title).font(.largeTitle.bold())
                        Text(project.artist.isEmpty ? "Kein Artist gesetzt" : project.artist)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Logic neu importieren", systemImage: "square.and.arrow.down", action: onImportLogic)
                    Button("Lyrics", systemImage: "text.quote", action: onImportLyrics)
                }

                HStack(spacing: 14) {
                    MetricCard(title: "Länge", value: format(project.duration))
                    MetricCard(title: "Tempo", value: project.bpm.map { "\(Int($0.rounded())) BPM" } ?? "—")
                    MetricCard(title: "Marker", value: "\(project.markers.count)")
                    MetricCard(title: "Stems", value: "\(project.stemURLs.count)")
                }

                GroupBox("Waveform") {
                    Group {
                        if project.waveform.isEmpty {
                            ContentUnavailableView(
                                "Noch kein Audio",
                                systemImage: "waveform",
                                description: Text("Importiere einen Logic-Export mit Master-Audio.")
                            )
                        } else {
                            WaveformView(samples: project.waveform)
                        }
                    }
                    .frame(height: 150)
                    .padding(.vertical, 6)
                }

                HStack(alignment: .top, spacing: 18) {
                    GroupBox("Marker") {
                        VStack(alignment: .leading, spacing: 10) {
                            if project.markers.isEmpty {
                                Text("Keine MIDI-Marker importiert.").foregroundStyle(.secondary)
                            } else {
                                ForEach(project.markers) { marker in
                                    HStack {
                                        Text(format(marker.time)).monospacedDigit().foregroundStyle(.secondary)
                                            .frame(width: 66, alignment: .leading)
                                        Text(marker.name)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    GroupBox("Lyrics") {
                        VStack(alignment: .leading, spacing: 8) {
                            if project.lyrics.isEmpty {
                                Text("Noch keine Lyrics importiert.").foregroundStyle(.secondary)
                            } else {
                                ForEach(project.lyrics.prefix(12)) { line in
                                    HStack(alignment: .top) {
                                        if let start = line.start {
                                            Text(format(start)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                                .frame(width: 54, alignment: .leading)
                                        }
                                        Text(line.text)
                                        Spacer()
                                    }
                                }
                                if project.lyrics.count > 12 {
                                    Text("+ \(project.lyrics.count - 12) weitere Zeilen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
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

struct ReferenceLibraryView: View {
    @Binding var project: SongProject
    @State private var showImporter = false
    @State private var importKind: VisualReferenceKind = .person
    @State private var selectedID: UUID?
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Referenzen").font(.largeTitle.bold())
                    Text("Diese Bilder halten Personen, Outfits, Locations und Stil über alle Shots konsistent.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Typ", selection: $importKind) {
                    ForEach(VisualReferenceKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .frame(width: 140)
                Button("Bilder hinzufügen", systemImage: "plus") { showImporter = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    ForEach(project.references) { reference in
                        ReferenceCard(reference: reference, selected: selectedID == reference.id)
                            .onTapGesture { selectedID = reference.id }
                            .contextMenu {
                                Button("Entfernen", role: .destructive) {
                                    project.references.removeAll { $0.id == reference.id }
                                    if selectedID == reference.id { selectedID = nil }
                                }
                            }
                    }

                    Button { showImporter = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus.circle").font(.largeTitle)
                            Text("Referenz hinzufügen")
                        }
                        .frame(maxWidth: .infinity, minHeight: 170)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(28)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true,
            onCompletion: importReferences
        )
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

    private func importReferences(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            for url in urls {
                project.references.append(
                    VisualReference(
                        name: url.deletingPathExtension().lastPathComponent,
                        kind: importKind,
                        fileURL: url
                    )
                )
            }
        }
    }
}

private struct ReferenceCard: View {
    let reference: VisualReference
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReferenceImage(url: reference.fileURL)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reference.name).font(.headline).lineLimit(1)
                    Text(reference.kind.label).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: kindIcon(reference.kind)).foregroundStyle(Color.accentColor)
            }
        }
        .padding(10)
        .background(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        }
    }

    private func kindIcon(_ kind: VisualReferenceKind) -> String {
        switch kind {
        case .person: return "person.crop.rectangle"
        case .outfit: return "tshirt"
        case .location: return "mappin.and.ellipse"
        case .style: return "paintpalette"
        }
    }
}

private struct ReferenceImage: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StoryboardView: View {
    @Binding var project: SongProject
    @ObservedObject var renderQueue: RenderQueueModel

    @State private var providerMode: ProviderMode = .mock
    @State private var renderError: String?

    enum ProviderMode: String, CaseIterable, Identifiable {
        case mock = "Mock"
        case runway = "Runway"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storyboard").font(.largeTitle.bold())
                    Text("Plane einzelne Shots, verknüpfe Referenzen und rendere mehrere Takes.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Provider", selection: $providerMode) {
                    ForEach(ProviderMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Button("Auto-Storyboard", systemImage: "wand.and.stars") { createAutomaticStoryboard() }
                Button("Shot", systemImage: "plus") { addShot() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            Divider()

            if project.shots.isEmpty {
                ContentUnavailableView(
                    "Noch kein Storyboard",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Erzeuge automatisch Shots aus Logic-Markern oder füge den ersten Shot manuell hinzu.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(project.shots.indices, id: \.self) { index in
                            ShotEditorCard(
                                shot: $project.shots[index],
                                references: project.references,
                                onRender: { renderShot(index: index) }
                            )
                        }
                    }
                    .padding(28)
                }
            }
        }
        .alert(
            "Render fehlgeschlagen",
            isPresented: Binding(
                get: { renderError != nil },
                set: { if !$0 { renderError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { renderError = nil }
        } message: {
            Text(renderError ?? "Unbekannter Fehler")
        }
    }

    private func addShot() {
        let start = project.shots.last.map { $0.start + $0.duration } ?? 0
        project.shots.append(
            VideoShot(
                start: min(start, project.duration),
                duration: 5,
                prompt: "Cinematic performance shot, realistic lighting, natural movement"
            )
        )
    }

    private func createAutomaticStoryboard() {
        if !project.markers.isEmpty {
            let sorted = project.markers.sorted { $0.time < $1.time }
            project.shots = sorted.enumerated().map { index, marker in
                let next = index + 1 < sorted.count ? sorted[index + 1].time : project.duration
                let length = max(3, min(8, next - marker.time))
                return VideoShot(
                    start: marker.time,
                    duration: length,
                    prompt: "\(marker.name): realistic cinematic music-video shot, expressive performance, natural camera movement"
                )
            }
        } else {
            let songLength = max(5, project.duration)
            project.shots = stride(from: 0.0, to: songLength, by: 5.0).map { start in
                VideoShot(
                    start: start,
                    duration: min(5, songLength - start),
                    prompt: "Realistic cinematic music-video shot, expressive performance, natural camera movement"
                )
            }
        }
    }

    private func renderShot(index: Int) {
        guard project.shots.indices.contains(index) else { return }
        let shot = project.shots[index]
        let references = project.references.filter { shot.referenceIDs.contains($0.id) }
        let provider: any VideoProvider = providerMode == .runway ? RunwayVideoProvider() : MockVideoProvider()
        project.shots[index].status = .rendering

        Task {
            let take = await renderQueue.render(
                projectID: project.id,
                shot: shot,
                references: references,
                provider: provider
            )

            guard let currentIndex = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
            project.shots[currentIndex].takes.append(take)
            if take.status == .ready {
                project.shots[currentIndex].status = .review
            } else {
                project.shots[currentIndex].status = .failed
                renderError = take.errorMessage
            }
        }
    }
}

private struct ShotEditorCard: View {
    @Binding var shot: VideoShot
    let references: [VisualReference]
    let onRender: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(timeLabel, systemImage: "film")
                    .font(.headline)
                StatusPill(text: shot.status.rawValue.capitalized)
                Spacer()
                Menu {
                    if references.isEmpty {
                        Text("Noch keine Referenzen")
                    } else {
                        ForEach(references) { reference in
                            Button {
                                toggleReference(reference.id)
                            } label: {
                                Label(
                                    reference.name,
                                    systemImage: shot.referenceIDs.contains(reference.id) ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    }
                } label: {
                    Label("Referenzen \(shot.referenceIDs.count)", systemImage: "photo.stack")
                }
                Button("Rendern", systemImage: "sparkles", action: onRender)
                    .buttonStyle(.borderedProminent)
            }

            TextField("Shot-Prompt", text: $shot.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            HStack {
                VStack(alignment: .leading) {
                    Text("Start").font(.caption).foregroundStyle(.secondary)
                    TextField("0", value: $shot.start, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                VStack(alignment: .leading) {
                    Text("Dauer").font(.caption).foregroundStyle(.secondary)
                    TextField("5", value: $shot.duration, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                Spacer()
            }

            if !shot.takes.isEmpty {
                Divider()
                Text("Takes").font(.headline)
                ForEach(shot.takes) { take in
                    HStack {
                        Image(systemName: take.status == .ready ? "checkmark.circle.fill" : take.status == .failed ? "exclamationmark.triangle.fill" : "clock")
                        Text(take.provider)
                        Text(take.createdAt, style: .time).foregroundStyle(.secondary)
                        Spacer()
                        if let outputURL = take.outputURL {
                            Link("Öffnen", destination: outputURL)
                        }
                        if take.status == .ready {
                            Button(shot.selectedTakeID == take.id ? "Freigegeben" : "Take wählen") {
                                shot.selectedTakeID = take.id
                                shot.status = .approved
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 14))
    }

    private var timeLabel: String {
        String(format: "%02d:%02d · %.1fs", Int(shot.start) / 60, Int(shot.start) % 60, shot.duration)
    }

    private func toggleReference(_ id: UUID) {
        if let index = shot.referenceIDs.firstIndex(of: id) {
            shot.referenceIDs.remove(at: index)
        } else {
            shot.referenceIDs.append(id)
        }
    }
}

struct RenderQueueView: View {
    @ObservedObject var model: RenderQueueModel
    let projects: [SongProject]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Render Queue").font(.largeTitle.bold())
                Text("Alle laufenden, fertigen und fehlgeschlagenen KI-Shots.")
                    .foregroundStyle(.secondary)
            }

            if model.items.isEmpty {
                ContentUnavailableView(
                    "Noch keine Renderaufträge",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Rendere im Storyboard einen Shot mit Mock oder Runway.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.items) { item in
                    HStack {
                        Image(systemName: queueIcon(item.status))
                        VStack(alignment: .leading) {
                            Text(projects.first(where: { $0.id == item.projectID })?.title ?? "Projekt")
                            Text("\(item.providerName) · \(item.status.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let url = item.outputURL { Link("Ergebnis", destination: url) }
                        if let error = item.errorMessage {
                            Text(error).font(.caption).foregroundStyle(.red).lineLimit(1)
                                .frame(maxWidth: 260, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(28)
    }

    private func queueIcon(_ status: RenderQueueItem.Status) -> String {
        switch status {
        case .queued: return "clock"
        case .rendering: return "sparkles"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct LiveModeView: View {
    let projects: [SongProject]
    @Binding var entries: [LiveSetEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Mode").font(.largeTitle.bold())
                    Text("Setlist und spontane Zugaben. Matamike kann Songs direkt hier eintragen.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GroupBox("Zugaben") {
                VStack(alignment: .leading, spacing: 10) {
                    let encores = entries.filter(\.isEncore)
                    if encores.isEmpty {
                        Text("Noch keine Zugabe. Sag Matamike z. B. „Pack Demo Song als Zugabe rein“.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(encores) { entry in
                            HStack {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text(entry.title).font(.headline)
                                Spacer()
                                Text("Zugabe").font(.caption).foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    entries.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            GroupBox("Songs verfügbar") {
                VStack(spacing: 0) {
                    ForEach(projects) { project in
                        HStack {
                            Text(project.title)
                            Spacer()
                            Button("Als Zugabe") {
                                addEncore(project)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                        if project.id != projects.last?.id { Divider() }
                    }
                }
            }

            Spacer()
        }
        .padding(28)
    }

    private func addEncore(_ project: SongProject) {
        guard !entries.contains(where: { $0.projectID == project.id && $0.isEncore }) else { return }
        entries.append(LiveSetEntry(projectID: project.id, title: project.title, isEncore: true))
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage).font(.title2)
                Spacer()
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Text(subtitle).font(.caption).foregroundStyle(prominent ? Color.white.opacity(0.78) : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .padding(16)
            .background(
                prominent ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.secondary.opacity(0.10)),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(prominent ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

struct WaveformView: View {
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
                context.stroke(path, with: .color(.accentColor), lineWidth: max(1, width * 0.7))
            }
        }
        .padding(.vertical, 8)
        .accessibilityLabel("Audio waveform")
    }
}

private struct WorkflowStrip: View {
    private let steps = [
        ("1", "Import", "Logic übernehmen"),
        ("2", "Lyrics", "Text und Timing"),
        ("3", "Referenzen", "Personen & Orte"),
        ("4", "Storyboard", "Shots planen"),
        ("5", "Video", "KI-Takes rendern"),
        ("6", "Export", "Finales Video")
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(steps, id: \.0) { step in
                HStack(spacing: 10) {
                    Text(step.0)
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.1).font(.headline)
                        Text(step.2).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if step.0 != "6" { Spacer(minLength: 4) }
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
    }
}
