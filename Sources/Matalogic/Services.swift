import Foundation

struct LogicExchangePackage {
    var rootURL: URL
    var masterAudioURL: URL?
    var midiURL: URL?
    var aafURL: URL?
    var stemURLs: [URL]
    var lyricsURL: URL?
}

protocol LogicImporting {
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

        let master = files.first { ["wav", "aif", "aiff", "m4a"].contains($0.pathExtension.lowercased()) }
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
            ).filter { ["wav", "aif", "aiff", "m4a"].contains($0.pathExtension.lowercased()) }) ?? []
        } else {
            stems = []
        }

        return LogicExchangePackage(
            rootURL: url,
            masterAudioURL: master,
            midiURL: midi,
            aafURL: aaf,
            stemURLs: stems,
            lyricsURL: lyrics
        )
    }

    func importProject(from package: LogicExchangePackage) async throws -> SongProject {
        guard package.masterAudioURL != nil else {
            throw LogicImportError.missingAudio
        }

        // TODO: Read duration from AVFoundation, then parse tempo/markers from MIDI.
        // AAF is intentionally treated as optional enrichment rather than the primary project format.
        return SongProject(
            title: package.rootURL.lastPathComponent,
            markers: [],
            lyrics: package.lyricsURL.map(Self.readPlainLyrics) ?? []
        )
    }

    private static func readPlainLyrics(from url: URL) -> [LyricLine] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content
            .split(whereSeparator: \.isNewline)
            .map { LyricLine(text: String($0)) }
    }
}

struct VideoGenerationRequest {
    var shot: VideoShot
    var references: [VisualReference]
    var aspectRatio: String = "16:9"
}

struct VideoGenerationResult {
    var providerJobID: String
    var outputURL: URL?
}

protocol VideoProvider {
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
