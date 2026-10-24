import AVFoundation
import Foundation

struct AudioAnalysis: Sendable {
    var duration: TimeInterval
    var waveform: [Float]
}

struct AudioAnalysisService: Sendable {
    func analyze(url: URL, targetWaveformPoints: Int = 720) async throws -> AudioAnalysis {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let waveform = try readWaveform(url: url, targetPoints: targetWaveformPoints)
        return AudioAnalysis(duration: duration.isFinite ? duration : 0, waveform: waveform)
    }

    private func readWaveform(url: URL, targetPoints: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = Int(file.length)

        guard totalFrames > 0, targetPoints > 0 else { return [] }

        let framesPerPoint = max(512, totalFrames / targetPoints)
        let capacity = AVAudioFrameCount(min(max(framesPerPoint, 512), 131_072))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return []
        }

        var peaks: [Float] = []
        peaks.reserveCapacity(targetPoints + 8)

        while file.framePosition < file.length {
            let remaining = file.length - file.framePosition
            let requested = AVAudioFrameCount(min(Int64(capacity), remaining))
            try file.read(into: buffer, frameCount: requested)

            guard let channels = buffer.floatChannelData else { continue }
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(format.channelCount)
            guard frameCount > 0, channelCount > 0 else { continue }

            var peak: Float = 0
            for channel in 0..<channelCount {
                let samples = channels[channel]
                for index in 0..<frameCount {
                    peak = max(peak, abs(samples[index]))
                }
            }
            peaks.append(peak)
        }

        guard let maximum = peaks.max(), maximum > 0 else { return peaks }
        let normalized = peaks.map { min(1, $0 / maximum) }
        return downsample(normalized, targetCount: targetPoints)
    }

    private func downsample(_ values: [Float], targetCount: Int) -> [Float] {
        guard values.count > targetCount, targetCount > 0 else { return values }

        let stride = Double(values.count) / Double(targetCount)
        return (0..<targetCount).map { index in
            let start = Int(Double(index) * stride)
            let end = min(values.count, max(start + 1, Int(Double(index + 1) * stride)))
            return values[start..<end].max() ?? 0
        }
    }
}

enum LyricsImportError: LocalizedError {
    case unreadable
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The lyrics file could not be read."
        case .unsupportedFormat:
            return "Supported lyric formats are TXT, LRC and SRT."
        }
    }
}

struct LyricsImportService: Sendable {
    func parse(url: URL) throws -> [LyricLine] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw LyricsImportError.unreadable
        }

        switch url.pathExtension.lowercased() {
        case "txt":
            return parsePlainText(content)
        case "lrc":
            return parseLRC(content)
        case "srt":
            return parseSRT(content)
        default:
            throw LyricsImportError.unsupportedFormat
        }
    }

    func parsePlainText(_ content: String) -> [LyricLine] {
        content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { LyricLine(text: $0) }
    }

    func parseLRC(_ content: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in content.split(whereSeparator: \.isNewline).map(String.init) {
            var remainder = rawLine
            var timestamps: [TimeInterval] = []

            while remainder.first == "[", let closing = remainder.firstIndex(of: "]") {
                let token = String(remainder[remainder.index(after: remainder.startIndex)..<closing])
                guard let time = parseLRCTimestamp(token) else { break }
                timestamps.append(time)
                remainder = String(remainder[remainder.index(after: closing)...])
            }

            let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            for time in timestamps {
                lines.append(LyricLine(text: text, start: time))
            }
        }

        lines.sort { ($0.start ?? 0) < ($1.start ?? 0) }
        for index in lines.indices.dropLast() {
            lines[index].end = lines[index + 1].start
        }
        return lines
    }

    func parseSRT(_ content: String) -> [LyricLine] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var result: [LyricLine] = []

        for block in blocks {
            let rows = block
                .split(whereSeparator: \.isNewline)
                .map(String.init)
            guard let timeRow = rows.first(where: { $0.contains("-->") }) else { continue }

            let parts = timeRow.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = parseSRTTimestamp(parts[0]),
                  let end = parseSRTTimestamp(parts[1]) else { continue }

            let textRows = rows.filter { row in
                row != timeRow && Int(row.trimmingCharacters(in: .whitespaces)) == nil
            }
            let text = textRows.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            result.append(LyricLine(text: text, start: start, end: end))
        }

        return result.sorted { ($0.start ?? 0) < ($1.start ?? 0) }
    }

    private func parseLRCTimestamp(_ value: String) -> TimeInterval? {
        let components = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else { return nil }
        return minutes * 60 + seconds
    }

    private func parseSRTTimestamp(_ value: String) -> TimeInterval? {
        let cleaned = value.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":").map(String.init)
        guard parts.count == 3, let hours = Double(parts[0]), let minutes = Double(parts[1]) else { return nil }

        let secondsParts = parts[2].replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(secondsParts) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}
