import Foundation

struct LogicExchangePackage: Sendable {
    var rootURL: URL
    var masterAudioURL: URL?
    var midiURL: URL?
    var aafURL: URL?
    var stemURLs: [URL]
    var trackAssets: [AudioTrackAsset]
    var lyricsURL: URL?
    var references: [VisualReference]
}

protocol LogicImporting: Sendable {
    func discoverPackage(at url: URL) throws -> LogicExchangePackage
    func importProject(from package: LogicExchangePackage) async throws -> SongProject
}

enum LogicImportError: LocalizedError {
    case notDirectory
    case missingAudio

    var errorDescription: String? {
        switch self {
        case .notDirectory:
            return "Der ausgewählte Logic-Austausch ist kein Ordner."
        case .missingAudio:
            return "Im ausgewählten Ordner wurden keine Audio-Dateien gefunden."
        }
    }
}

struct LogicImportService: LogicImporting {
    private let fileManager = FileManager.default
    private let audioService = AudioAnalysisService()
    private let midiParser = StandardMIDIParser()
    private let lyricsService = LyricsImportService()
    private let audioExtensions = Set(["wav", "aif", "aiff", "m4a", "caf", "mp3", "aac"])
    private let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "webp", "tif", "tiff"])

    func discoverPackage(at url: URL) throws -> LogicExchangePackage {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LogicImportError.notDirectory
        }

        let rootFiles = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let rootAudio = rootFiles.filter(isAudioFile)
        let nestedAudio = audioFiles(inNamedFolders: ["Tracks", "Spuren", "Stems", "Audio", "Audio Files"], root: url)
        let allAudio = uniqueURLs(rootAudio + nestedAudio)
        guard !allAudio.isEmpty else { throw LogicImportError.missingAudio }

        let master = chooseMaster(from: rootAudio)
        let trackURLs = allAudio.filter { $0 != master }
        let trackAssets = trackURLs
            .map { AudioTrackAsset(name: displayName(for: $0), fileURL: $0, role: inferRole(from: $0)) }
            .sorted { lhs, rhs in
                if lhs.role == rhs.role {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return roleSortIndex(lhs.role) < roleSortIndex(rhs.role)
            }

        let midi = rootFiles.first { ["mid", "midi"].contains($0.pathExtension.lowercased()) }
        let aaf = rootFiles.first { $0.pathExtension.lowercased() == "aaf" }
        let lyrics = rootFiles.first { ["txt", "lrc", "srt"].contains($0.pathExtension.lowercased()) }

        return LogicExchangePackage(
            rootURL: url,
            masterAudioURL: master,
            midiURL: midi,
            aafURL: aaf,
            stemURLs: trackURLs.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending },
            trackAssets: trackAssets,
            lyricsURL: lyrics,
            references: discoverReferences(root: url)
        )
    }

    func importProject(from package: LogicExchangePackage) async throws -> SongProject {
        guard let analysisURL = package.masterAudioURL ?? package.trackAssets.first?.fileURL else {
            throw LogicImportError.missingAudio
        }

        let audio = try await audioService.analyze(url: analysisURL)
        let midi = try package.midiURL.map(midiParser.parse)
        let lyrics = try package.lyricsURL.map(lyricsService.parse) ?? []

        return SongProject(
            title: package.rootURL.lastPathComponent,
            duration: audio.duration,
            bpm: midi?.bpm,
            markers: midi?.markers ?? [],
            lyrics: lyrics,
            references: package.references,
            shots: [],
            masterAudioURL: package.masterAudioURL,
            stemURLs: package.stemURLs,
            trackAssets: package.trackAssets,
            midiURL: package.midiURL,
            aafURL: package.aafURL,
            sourceFolderURL: package.rootURL,
            waveform: audio.waveform
        )
    }

    private func isAudioFile(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    private func audioFiles(inNamedFolders names: [String], root: URL) -> [URL] {
        var result: [URL] = []
        for name in names {
            let folder = root.appendingPathComponent(name, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            let files = (try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            result.append(contentsOf: files.filter(isAudioFile))
        }
        return result
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private func chooseMaster(from urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }
        let preferred = ["master", "mixdown", "mix down", "full mix", "fullmix", "bounce", "stereo mix", "stereomix"]
        if let named = urls.first(where: { url in
            let name = displayName(for: url).lowercased()
            return preferred.contains(where: name.contains)
        }) {
            return named
        }
        return urls.count == 1 ? urls[0] : nil
    }

    private func displayName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func inferRole(from url: URL) -> AudioTrackRole {
        let name = displayName(for: url)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        if containsAny(name, ["backing vocal", "backing vox", "back vocal", "back vox", "bgv", "bvox", "choir", "chor", "harmony", "harmonie"]) {
            return .backingVocal
        }
        if containsAny(name, ["lead vocal", "lead vox", "leadvox", "main vocal", "main vox", "vocals", "vocal", "vox", "gesang", "hauptgesang", "stimme"]) {
            return .leadVocal
        }
        if containsAny(name, ["drum", "kick", "snare", "tom", "hihat", "hi hat", "overhead"]) { return .drums }
        if containsAny(name, ["bass"]) { return .bass }
        if containsAny(name, ["guitar", "gtr", "gitarre"]) { return .guitar }
        if containsAny(name, ["piano", "keys", "keyboard", "organ", "orgel", "rhodes"]) { return .keys }
        if containsAny(name, ["synth", "pad", "arp"]) { return .synth }
        if containsAny(name, ["perc", "shaker", "tamb", "clap"]) { return .percussion }
        return .other
    }

    private func containsAny(_ name: String, _ needles: [String]) -> Bool {
        needles.contains(where: name.contains)
    }

    private func roleSortIndex(_ role: AudioTrackRole) -> Int {
        switch role {
        case .leadVocal: return 0
        case .backingVocal: return 1
        case .drums: return 2
        case .bass: return 3
        case .guitar: return 4
        case .keys: return 5
        case .synth: return 6
        case .percussion: return 7
        case .other: return 8
        }
    }

    private func discoverReferences(root: URL) -> [VisualReference] {
        let referencesRoot = root.appendingPathComponent("References", isDirectory: true)
        var refs: [VisualReference] = []
        let folders: [(String, VisualReferenceKind)] = [
            ("People", .person),
            ("Persons", .person),
            ("Personen", .person),
            ("Singers", .person),
            ("Saenger", .person),
            ("Outfits", .outfit),
            ("Locations", .location),
            ("Style", .style),
            ("Stil", .style)
        ]

        for (folderName, kind) in folders {
            let folder = referencesRoot.appendingPathComponent(folderName, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            let urls = (try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for image in urls where imageExtensions.contains(image.pathExtension.lowercased()) {
                refs.append(
                    VisualReference(
                        name: displayName(for: image),
                        kind: kind,
                        fileURL: image,
                        notes: "Aus Logic-Austauschordner importiert"
                    )
                )
            }
        }
        return refs
    }
}

struct VideoGenerationRequest: Sendable {
    var shot: VideoShot
    var references: [VisualReference]
    var aspectRatio: String = "16:9"
}

struct VideoGenerationResult: Sendable {
    var providerJobID: String
    var outputURL: URL?
}

protocol VideoProvider: Sendable {
    var name: String { get }
    func generate(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult
}

struct MockVideoProvider: VideoProvider {
    let name = "Mock Renderer"

    func generate(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult {
        try await Task.sleep(nanoseconds: 750_000_000)
        return VideoGenerationResult(
            providerJobID: "mock-\(request.shot.id.uuidString)",
            outputURL: nil
        )
    }
}
