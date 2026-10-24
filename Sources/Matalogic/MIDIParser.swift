import Foundation

struct MIDIImportResult: Sendable {
    var bpm: Double?
    var markers: [SongMarker]
}

enum MIDIParseError: LocalizedError {
    case invalidHeader
    case unsupportedTiming
    case truncated

    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "The MIDI file has an invalid header."
        case .unsupportedTiming: return "SMPTE-timed MIDI files are not supported yet."
        case .truncated: return "The MIDI file appears to be truncated."
        }
    }
}

struct StandardMIDIParser: Sendable {
    private struct TempoEvent {
        var tick: UInt64
        var microsecondsPerQuarter: UInt32
    }

    private struct RawMarker {
        var tick: UInt64
        var name: String
    }

    func parse(url: URL) throws -> MIDIImportResult {
        try parse(data: Data(contentsOf: url))
    }

    func parse(data: Data) throws -> MIDIImportResult {
        var cursor = Cursor(data)
        guard try cursor.readASCII(4) == "MThd" else { throw MIDIParseError.invalidHeader }
        let headerLength = try cursor.readUInt32()
        guard headerLength >= 6 else { throw MIDIParseError.invalidHeader }
        _ = try cursor.readUInt16()
        let trackCount = Int(try cursor.readUInt16())
        let division = try cursor.readUInt16()
        guard division & 0x8000 == 0 else { throw MIDIParseError.unsupportedTiming }
        let ppq = UInt64(division)
        if headerLength > 6 { try cursor.skip(Int(headerLength - 6)) }

        var tempos: [TempoEvent] = [TempoEvent(tick: 0, microsecondsPerQuarter: 500_000)]
        var markers: [RawMarker] = []

        for _ in 0..<trackCount {
            guard try cursor.readASCII(4) == "MTrk" else { throw MIDIParseError.truncated }
            let length = Int(try cursor.readUInt32())
            let trackEnd = cursor.position + length
            var tick: UInt64 = 0
            var runningStatus: UInt8?

            while cursor.position < trackEnd {
                tick += UInt64(try cursor.readVariableLength())
                let first = try cursor.readByte()
                let status: UInt8
                var firstDataByte: UInt8?

                if first & 0x80 != 0 {
                    status = first
                    if status < 0xF0 { runningStatus = status }
                } else {
                    guard let runningStatus else { throw MIDIParseError.truncated }
                    status = runningStatus
                    firstDataByte = first
                }

                if status == 0xFF {
                    runningStatus = nil
                    let type = try cursor.readByte()
                    let metaLength = Int(try cursor.readVariableLength())
                    let payload = try cursor.readData(metaLength)

                    if type == 0x51, payload.count == 3 {
                        let value = (UInt32(payload[0]) << 16) | (UInt32(payload[1]) << 8) | UInt32(payload[2])
                        tempos.append(TempoEvent(tick: tick, microsecondsPerQuarter: value))
                    } else if type == 0x06, let text = String(data: payload, encoding: .utf8), !text.isEmpty {
                        markers.append(RawMarker(tick: tick, name: text))
                    }
                } else if status == 0xF0 || status == 0xF7 {
                    runningStatus = nil
                    let sysexLength = Int(try cursor.readVariableLength())
                    try cursor.skip(sysexLength)
                } else {
                    let high = status & 0xF0
                    let dataLength = (high == 0xC0 || high == 0xD0) ? 1 : 2
                    let alreadyRead = firstDataByte == nil ? 0 : 1
                    try cursor.skip(dataLength - alreadyRead)
                }
            }

            if cursor.position < trackEnd { try cursor.skip(trackEnd - cursor.position) }
        }

        tempos.sort { $0.tick < $1.tick }
        let firstTempo = tempos.first(where: { $0.tick == 0 })?.microsecondsPerQuarter ?? 500_000
        let bpm = 60_000_000.0 / Double(firstTempo)

        let converted = markers
            .map { SongMarker(name: $0.name, time: seconds(at: $0.tick, ppq: ppq, tempos: tempos)) }
            .sorted { $0.time < $1.time }

        return MIDIImportResult(bpm: bpm, markers: converted)
    }

    private func seconds(at tick: UInt64, ppq: UInt64, tempos: [TempoEvent]) -> TimeInterval {
        var currentTick: UInt64 = 0
        var currentTempo: UInt32 = 500_000
        var seconds: Double = 0

        for event in tempos where event.tick <= tick {
            if event.tick > currentTick {
                seconds += Double(event.tick - currentTick) * Double(currentTempo) / 1_000_000.0 / Double(ppq)
                currentTick = event.tick
            }
            currentTempo = event.microsecondsPerQuarter
        }

        if tick > currentTick {
            seconds += Double(tick - currentTick) * Double(currentTempo) / 1_000_000.0 / Double(ppq)
        }
        return seconds
    }
}

private struct Cursor {
    private let bytes: [UInt8]
    private(set) var position: Int = 0

    init(_ data: Data) { bytes = Array(data) }

    mutating func readByte() throws -> UInt8 {
        guard position < bytes.count else { throw MIDIParseError.truncated }
        defer { position += 1 }
        return bytes[position]
    }

    mutating func readData(_ count: Int) throws -> Data {
        guard count >= 0, position + count <= bytes.count else { throw MIDIParseError.truncated }
        let result = Data(bytes[position..<(position + count)])
        position += count
        return result
    }

    mutating func readASCII(_ count: Int) throws -> String {
        let data = try readData(count)
        guard let string = String(data: data, encoding: .ascii) else { throw MIDIParseError.truncated }
        return string
    }

    mutating func readUInt16() throws -> UInt16 {
        let a = UInt16(try readByte())
        let b = UInt16(try readByte())
        return (a << 8) | b
    }

    mutating func readUInt32() throws -> UInt32 {
        let a = UInt32(try readByte())
        let b = UInt32(try readByte())
        let c = UInt32(try readByte())
        let d = UInt32(try readByte())
        return (a << 24) | (b << 16) | (c << 8) | d
    }

    mutating func readVariableLength() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = try readByte()
            value = (value << 7) | UInt32(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        return value
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, position + count <= bytes.count else { throw MIDIParseError.truncated }
        position += count
    }
}
