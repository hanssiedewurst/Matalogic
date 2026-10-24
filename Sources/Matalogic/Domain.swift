import Foundation

struct SongProject: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    var duration: TimeInterval
    var bpm: Double?
    var markers: [SongMarker]
    var lyrics: [LyricLine]
    var references: [VisualReference]
    var shots: [VideoShot]
    var masterAudioURL: URL?
    var stemURLs: [URL]
    var trackAssets: [AudioTrackAsset]
    var midiURL: URL?
    var aafURL: URL?
    var sourceFolderURL: URL?
    var waveform: [Float]

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "",
        duration: TimeInterval = 0,
        bpm: Double? = nil,
        markers: [SongMarker] = [],
        lyrics: [LyricLine] = [],
        references: [VisualReference] = [],
        shots: [VideoShot] = [],
        masterAudioURL: URL? = nil,
        stemURLs: [URL] = [],
        trackAssets: [AudioTrackAsset] = [],
        midiURL: URL? = nil,
        aafURL: URL? = nil,
        sourceFolderURL: URL? = nil,
        waveform: [Float] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.bpm = bpm
        self.markers = markers
        self.lyrics = lyrics
        self.references = references
        self.shots = shots
        self.masterAudioURL = masterAudioURL
        self.stemURLs = stemURLs
        self.trackAssets = trackAssets
        self.midiURL = midiURL
        self.aafURL = aafURL
        self.sourceFolderURL = sourceFolderURL
        self.waveform = waveform
    }

    var vocalTracks: [AudioTrackAsset] {
        trackAssets.filter { $0.role == .leadVocal || $0.role == .backingVocal }
    }
}

enum AudioTrackRole: String, CaseIterable, Hashable, Sendable, Identifiable {
    case leadVocal
    case backingVocal
    case drums
    case bass
    case guitar
    case keys
    case synth
    case percussion
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leadVocal: return "Lead Vocals"
        case .backingVocal: return "Backing Vocals"
        case .drums: return "Drums"
        case .bass: return "Bass"
        case .guitar: return "Gitarre"
        case .keys: return "Keys"
        case .synth: return "Synth"
        case .percussion: return "Percussion"
        case .other: return "Andere"
        }
    }
}

struct AudioTrackAsset: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var fileURL: URL
    var role: AudioTrackRole

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        role: AudioTrackRole = .other
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.role = role
    }
}

struct SongMarker: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var time: TimeInterval

    init(id: UUID = UUID(), name: String, time: TimeInterval) {
        self.id = id
        self.name = name
        self.time = time
    }
}

struct LyricLine: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var start: TimeInterval?
    var end: TimeInterval?

    init(id: UUID = UUID(), text: String, start: TimeInterval? = nil, end: TimeInterval? = nil) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
    }
}

enum VisualReferenceKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    case person
    case outfit
    case location
    case style

    var id: String { rawValue }

    var label: String {
        switch self {
        case .person: return "Person"
        case .outfit: return "Outfit"
        case .location: return "Location"
        case .style: return "Stil"
        }
    }
}

struct VisualReference: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: VisualReferenceKind
    var fileURL: URL?
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        kind: VisualReferenceKind,
        fileURL: URL? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.fileURL = fileURL
        self.notes = notes
    }
}

struct VideoTake: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case queued
        case rendering
        case ready
        case failed
    }

    let id: UUID
    var provider: String
    var providerJobID: String?
    var outputURL: URL?
    var status: Status
    var createdAt: Date
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        provider: String,
        providerJobID: String? = nil,
        outputURL: URL? = nil,
        status: Status = .queued,
        createdAt: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.providerJobID = providerJobID
        self.outputURL = outputURL
        self.status = status
        self.createdAt = createdAt
        self.errorMessage = errorMessage
    }
}

struct VideoShot: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case draft
        case queued
        case rendering
        case review
        case approved
        case failed
    }

    let id: UUID
    var start: TimeInterval
    var duration: TimeInterval
    var prompt: String
    var status: Status
    var referenceIDs: [UUID]
    var takes: [VideoTake]
    var selectedTakeID: UUID?

    init(
        id: UUID = UUID(),
        start: TimeInterval,
        duration: TimeInterval,
        prompt: String,
        status: Status = .draft,
        referenceIDs: [UUID] = [],
        takes: [VideoTake] = [],
        selectedTakeID: UUID? = nil
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.prompt = prompt
        self.status = status
        self.referenceIDs = referenceIDs
        self.takes = takes
        self.selectedTakeID = selectedTakeID
    }
}

struct RenderQueueItem: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case queued
        case rendering
        case ready
        case failed
    }

    let id: UUID
    let projectID: UUID
    let shotID: UUID
    let takeID: UUID
    var providerName: String
    var status: Status
    var providerJobID: String?
    var outputURL: URL?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        projectID: UUID,
        shotID: UUID,
        takeID: UUID,
        providerName: String,
        status: Status = .queued,
        providerJobID: String? = nil,
        outputURL: URL? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.shotID = shotID
        self.takeID = takeID
        self.providerName = providerName
        self.status = status
        self.providerJobID = providerJobID
        self.outputURL = outputURL
        self.errorMessage = errorMessage
    }
}

struct LiveSetEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let projectID: UUID
    var title: String
    var isEncore: Bool
    var addedAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String,
        isEncore: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.isEncore = isEncore
        self.addedAt = addedAt
    }
}
