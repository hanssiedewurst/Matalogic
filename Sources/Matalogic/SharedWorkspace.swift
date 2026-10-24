import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SharedProjectCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let trackCount: Int
    let vocalCount: Int
    let referenceCount: Int
    let hasMIDI: Bool
    let hasAAF: Bool

    init(url: URL, package: LogicExchangePackage) {
        self.id = url.standardizedFileURL.path
        self.title = url.lastPathComponent
        self.url = url
        self.trackCount = package.trackAssets.count
        self.vocalCount = package.trackAssets.filter { $0.role == .leadVocal || $0.role == .backingVocal }.count
        self.referenceCount = package.references.count
        self.hasMIDI = package.midiURL != nil
        self.hasAAF = package.aafURL != nil
    }
}

@MainActor
final class SharedWorkspaceModel: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var projects: [SharedProjectCandidate] = []
    @Published private(set) var errorMessage: String?

    private let bookmarkKey = "matalogic.shared-workspace.bookmark"
    private let fileManager = FileManager.default
    private let importer = LogicImportService()
    private var activeScopedURL: URL?

    init() {
        restoreBookmark()
        refresh()
    }

    deinit {
        activeScopedURL?.stopAccessingSecurityScopedResource()
    }

    func selectRoot(_ url: URL) {
        activateSecurityScope(for: url)
        rootURL = url
        saveBookmark(url)
        refresh()
    }

    func refresh() {
        guard let rootURL else {
            projects = []
            return
        }

        do {
            let children = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            projects = children.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { return nil }
                guard let package = try? importer.discoverPackage(at: url) else { return nil }
                return SharedProjectCandidate(url: url, package: package)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            errorMessage = nil
        } catch {
            projects = []
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        activeScopedURL?.stopAccessingSecurityScopedResource()
        activeScopedURL = nil
        rootURL = nil
        projects = []
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private func saveBookmark(_ url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            errorMessage = "Austauschordner konnte nicht dauerhaft gespeichert werden: \(error.localizedDescription)"
        }
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            activateSecurityScope(for: url)
            rootURL = url
            if stale { saveBookmark(url) }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            errorMessage = "Gespeicherter Austauschordner konnte nicht geöffnet werden. Bitte neu auswählen."
        }
    }

    private func activateSecurityScope(for url: URL) {
        if activeScopedURL?.standardizedFileURL != url.standardizedFileURL {
            activeScopedURL?.stopAccessingSecurityScopedResource()
            activeScopedURL = nil
        }
        if activeScopedURL == nil, url.startAccessingSecurityScopedResource() {
            activeScopedURL = url
        }
    }
}

struct SharedWorkspaceView: View {
    @ObservedObject var model: SharedWorkspaceModel
    let onImport: (URL) -> Void

    @State private var showFolderImporter = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Austausch")
                        .font(.largeTitle.bold())
                    Text("Ein gemeinsamer Ordner für Logic-Exports, Referenzbilder und Matalogic-Projekte auf beiden Macs.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Aktualisieren", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(model.rootURL == nil)
                Button("Ordner wählen", systemImage: "folder") { showFolderImporter = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)

            Divider()

            if let root = model.rootURL {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GroupBox("Gemeinsamer Ordner") {
                            HStack {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(root.lastPathComponent).font(.headline)
                                    Text(root.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                                Spacer()
                                Button("Trennen") { model.clear() }
                            }
                            .padding(.vertical, 6)
                        }

                        GroupBox("Erkannte Songs") {
                            VStack(spacing: 0) {
                                if model.projects.isEmpty {
                                    CompatUnavailableView(
                                        title: "Noch keine Logic-Exports gefunden",
                                        systemImage: "music.note.list",
                                        description: "Lege pro Song einen Unterordner mit Master oder exportierten Einzelspuren an."
                                    )
                                    .frame(height: 220)
                                } else {
                                    ForEach(model.projects) { project in
                                        HStack(spacing: 14) {
                                            Image(systemName: project.vocalCount > 0 ? "music.mic" : "waveform")
                                                .font(.title3)
                                                .foregroundStyle(Color.accentColor)
                                                .frame(width: 34)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(project.title).font(.headline)
                                                HStack(spacing: 10) {
                                                    Text("\(project.trackCount) Spuren")
                                                    if project.vocalCount > 0 { Text("\(project.vocalCount) Vocal") }
                                                    if project.referenceCount > 0 { Text("\(project.referenceCount) Bilder") }
                                                    if project.hasMIDI { Text("MIDI") }
                                                    if project.hasAAF { Text("AAF") }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            }

                                            Spacer()
                                            Button("Importieren") { onImport(project.url) }
                                                .buttonStyle(.bordered)
                                        }
                                        .padding(.vertical, 12)

                                        if project.id != model.projects.last?.id { Divider() }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }

                        GroupBox("Empfohlener Song-Ordner") {
                            Text("""
                            Songname/
                            ├── Master.wav
                            ├── Songname.mid
                            ├── Songname.aaf            optional
                            ├── Tracks/                 Logic: Alle Spuren als Audiodateien
                            │   ├── Lead Vocal.wav
                            │   ├── Backing Vocal.wav
                            │   ├── Drums.wav
                            │   └── ...
                            └── References/
                                ├── People/
                                ├── Outfits/
                                ├── Locations/
                                └── Style/
                            """)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(28)
                }
            } else {
                CompatUnavailableView(
                    title: "Austauschordner auswählen",
                    systemImage: "folder.badge.plus",
                    description: "Wähle einen Ordner, auf den dein Intel-iMac und das Apple-Silicon-MacBook zugreifen können."
                ) {
                    Button("Ordner wählen") { showFolderImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.selectRoot(url)
            }
        }
    }
}

struct CompatUnavailableView<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String
    @ViewBuilder let actions: Actions

    init(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

extension CompatUnavailableView where Actions == EmptyView {
    init(title: String, systemImage: String, description: String) {
        self.init(title: title, systemImage: systemImage, description: description) { EmptyView() }
    }
}
