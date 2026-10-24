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
        // Format 0, one track, PPQ 480. Tempo 120 BPM at tick 0,
        // then a marker named "Verse" at tick 480 (one quarter note = 0.5 s).
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
}
