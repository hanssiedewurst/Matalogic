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
    var midiURL: URL?
    var aafURL: URL?
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
        midiURL: URL? = nil,
        aafURL: URL? = nil,
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
        self.midiURL = midiURL
        self.aafURL = aafURL
        self.waveform = waveform
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

enum VisualReferenceKind: String, CaseIterable, Hashable, Sendable {
    case person
    case outfit
    case location
    case style
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

    init(
        id: UUID = UUID(),
        start: TimeInterval,
        duration: TimeInterval,
        prompt: String,
        status: Status = .draft,
        referenceIDs: [UUID] = []
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.prompt = prompt
        self.status = status
        self.referenceIDs = referenceIDs
    }
}
