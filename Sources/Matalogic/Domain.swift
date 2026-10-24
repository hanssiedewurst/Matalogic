import Foundation

struct SongProject: Identifiable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var duration: TimeInterval
    var bpm: Double?
    var markers: [SongMarker]
    var lyrics: [LyricLine]
    var references: [VisualReference]
    var shots: [VideoShot]

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "",
        duration: TimeInterval = 0,
        bpm: Double? = nil,
        markers: [SongMarker] = [],
        lyrics: [LyricLine] = [],
        references: [VisualReference] = [],
        shots: [VideoShot] = []
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
    }
}

struct SongMarker: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var time: TimeInterval
}

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var start: TimeInterval?
    var end: TimeInterval?
}

enum VisualReferenceKind: String, CaseIterable, Hashable {
    case person
    case outfit
    case location
    case style
}

struct VisualReference: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var kind: VisualReferenceKind
    var fileURL: URL?
    var notes: String
}

struct VideoShot: Identifiable, Hashable {
    enum Status: String, Hashable {
        case draft
        case queued
        case rendering
        case review
        case approved
        case failed
    }

    let id = UUID()
    var start: TimeInterval
    var duration: TimeInterval
    var prompt: String
    var status: Status = .draft
    var referenceIDs: [UUID] = []
}
