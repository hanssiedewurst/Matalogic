import Foundation
import XCTest
@testable import Matalogic

final class ImportTests: XCTestCase {
    func testLRCImportParsesTiming() throws {
        let service = LyricsImportService()
        let lines = service.parseLRC("[00:01.50]First line\n[00:03.00]Second line")

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First line")
        XCTAssertEqual(lines[0].start ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(lines[0].end ?? 0, 3.0, accuracy: 0.001)
    }

    func testSRTImportParsesTimingAndText() throws {
        let service = LyricsImportService()
        let lines = service.parseSRT("""
        1
        00:00:02,000 --> 00:00:04,500
        Hello world
        """)

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Hello world")
        XCTAssertEqual(lines[0].start ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(lines[0].end ?? 0, 4.5, accuracy: 0.001)
    }

    func testMIDIImportParsesTempoAndMarker() throws {
        let bytes: [UInt8] = [
            0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
            0x00, 0x00, 0x00, 0x01, 0x01, 0xE0,
            0x4D, 0x54, 0x72, 0x6B, 0x00, 0x00, 0x00, 0x15,
            0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
            0x83, 0x60, 0xFF, 0x06, 0x05, 0x56, 0x65, 0x72, 0x73, 0x65,
            0x00, 0xFF, 0x2F, 0x00
        ]

        let result = try StandardMIDIParser().parse(data: Data(bytes))
        XCTAssertEqual(result.bpm ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(result.markers.count, 1)
        XCTAssertEqual(result.markers[0].name, "Verse")
        XCTAssertEqual(result.markers[0].time, 0.5, accuracy: 0.001)
    }

    func testLogicExportDiscoversVocalTracksAndSingerReferences() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tracks = root.appendingPathComponent("Tracks", isDirectory: true)
        let people = root.appendingPathComponent("References/People", isDirectory: true)
        try fm.createDirectory(at: tracks, withIntermediateDirectories: true)
        try fm.createDirectory(at: people, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        fm.createFile(atPath: root.appendingPathComponent("Master.wav").path, contents: Data())
        fm.createFile(atPath: tracks.appendingPathComponent("Lead Vocal.wav").path, contents: Data())
        fm.createFile(atPath: tracks.appendingPathComponent("Backing Vox.wav").path, contents: Data())
        fm.createFile(atPath: tracks.appendingPathComponent("Drums.wav").path, contents: Data())
        fm.createFile(atPath: people.appendingPathComponent("Singer A.jpg").path, contents: Data())

        let package = try LogicImportService().discoverPackage(at: root)

        XCTAssertEqual(package.masterAudioURL?.lastPathComponent, "Master.wav")
        XCTAssertEqual(package.trackAssets.count, 3)
        XCTAssertEqual(package.trackAssets.filter { $0.role == .leadVocal }.count, 1)
        XCTAssertEqual(package.trackAssets.filter { $0.role == .backingVocal }.count, 1)
        XCTAssertEqual(package.trackAssets.filter { $0.role == .drums }.count, 1)
        XCTAssertEqual(package.references.count, 1)
        XCTAssertEqual(package.references.first?.kind, .person)
    }

    func testMatamikeCanAddKnownSongAsEncore() async throws {
        let song = SongProject(title: "Midnight Highway")
        let reply = await LocalMatamikeProvider().reply(
            to: "Pack Midnight Highway als Zugabe rein",
            project: nil,
            availableProjects: [song]
        )

        guard case .addEncore(let projectID, let title) = reply.action else {
            return XCTFail("Expected an addEncore action")
        }

        XCTAssertEqual(projectID, song.id)
        XCTAssertEqual(title, song.title)
    }
}
