import Foundation

struct LogicExchangePackage: Sendable {
    var rootURL: URL
    var masterAudioURL: URL?
    var midiURL: URL?
    var aafURL: URL?
    var stemURLs: [URL]
    var lyricsURL: URL?
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
            return "The selected Logic exchange package is not a folder."
        case .missingAudio:
            return "No master audio file was found in the selected package."
        }
    }
}

struct LogicImportService: LogicImporting {
    private let fileManager = FileManager.default
    private let audioService = AudioAnalysisService()
    private let midiParser = StandardMIDIParser()
    private let lyricsService = LyricsImportService()

    func discoverPackage(at url: URL) throws -> LogicExchangePackage {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LogicImportError.notDirectory
        }

        let files = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let audioExtensions = ["wav", "aif", "aiff", "m4a", "caf"]
        let master = files.first {
            audioExtensions.contains($0.pathExtension.lowercased()) &&
            !$0.lastPathComponent.lowercased().contains("stem")
        }
        let midi = files.first { ["mid", "midi"].contains($0.pathExtension.lowercased()) }
        let aaf = files.first { $0.pathExtension.lowercased() == "aaf" }
        let lyrics = files.first { ["txt", "lrc", "srt"].contains($0.pathExtension.lowercased()) }

        let stemsFolder = url.appending(path: "Stems", directoryHint: .isDirectory)
        let stems: [URL]
        if fileManager.fileExists(atPath: stemsFolder.path) {
            stems = (try? fileManager.contentsOfDirectory(
                at: stemsFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { audioExtensions.contains($0.pathExtension.lowercased()) }) ?? []
        } else {
            stems = []
        }

        return LogicExchangePackage(
            rootURL: url,
            masterAudioURL: master,
            midiURL: midi,
            aafURL: aaf,
            stemURLs: stems.sorted { $0.lastPathComponent < $1.lastPathComponent },
            lyricsURL: lyrics
        )
    }

    func importProject(from package: LogicExchangePackage) async throws -> SongProject {
        guard let masterAudioURL = package.masterAudioURL else {
            throw LogicImportError.missingAudio
        }

        let audio = try await audioService.analyze(url: masterAudioURL)
        let midi = try package.midiURL.map(midiParser.parse)
        let lyrics = try package.lyricsURL.map(lyricsService.parse) ?? []

        return SongProject(
            title: package.rootURL.lastPathComponent,
            duration: audio.duration,
            bpm: midi?.bpm,
            markers: midi?.markers ?? [],
            lyrics: lyrics,
            references: [],
            shots: [],
            masterAudioURL: masterAudioURL,
            stemURLs: package.stemURLs,
            midiURL: package.midiURL,
            aafURL: package.aafURL,
            waveform: audio.waveform
        )
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
        try await Task.sleep(for: .milliseconds(750))
        return VideoGenerationResult(
            providerJobID: "mock-\(request.shot.id.uuidString)",
            outputURL: nil
        )
    }
}
