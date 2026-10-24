import Foundation
import Speech

struct AppleSpeechLyricsTranscriber: Sendable {
    enum TranscriptionError: LocalizedError {
        case authorizationDenied
        case recognizerUnavailable
        case noResult

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Spracherkennung wurde nicht erlaubt. Aktiviere sie in den macOS-Datenschutzeinstellungen."
            case .recognizerUnavailable:
                return "Die macOS-Spracherkennung ist für die gewählte Sprache gerade nicht verfügbar."
            case .noResult:
                return "Aus der Vocal-Spur konnten keine Lyrics erkannt werden."
            }
        }
    }

    func transcribe(
        url: URL,
        locale: Locale = .current
    ) async throws -> [LyricLine] {
        let status = await authorizationStatus()
        guard status == .authorized else { throw TranscriptionError.authorizationDenied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let segments = try await recognize(recognizer: recognizer, request: request)
        let lines = makeLyricLines(from: segments)
        guard !lines.isEmpty else { throw TranscriptionError.noResult }
        return lines
    }

    private func authorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func recognize(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> [SFTranscriptionSegment] {
        try await withCheckedThrowingContinuation { continuation in
            let state = RecognitionContinuationState(continuation: continuation)
            state.task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    state.finish(.failure(error))
                    return
                }
                guard let result, result.isFinal else { return }
                state.finish(.success(result.bestTranscription.segments))
            }
        }
    }

    private func makeLyricLines(from segments: [SFTranscriptionSegment]) -> [LyricLine] {
        guard !segments.isEmpty else { return [] }

        var lines: [LyricLine] = []
        var words: [String] = []
        var lineStart: TimeInterval?
        var lineEnd: TimeInterval?
        var previousEnd: TimeInterval?

        func flush() {
            guard !words.isEmpty, let start = lineStart else { return }
            lines.append(
                LyricLine(
                    text: words.joined(separator: " "),
                    start: start,
                    end: lineEnd
                )
            )
            words.removeAll(keepingCapacity: true)
            lineStart = nil
            lineEnd = nil
        }

        for segment in segments {
            let start = segment.timestamp
            let end = segment.timestamp + segment.duration
            let gap = previousEnd.map { max(0, start - $0) } ?? 0

            if !words.isEmpty && (gap >= 1.1 || words.count >= 8) {
                flush()
            }

            if lineStart == nil { lineStart = start }
            let word = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            if !word.isEmpty { words.append(word) }
            lineEnd = end
            previousEnd = end
        }

        flush()
        return lines
    }
}

private final class RecognitionContinuationState: @unchecked Sendable {
    typealias Continuation = CheckedContinuation<[SFTranscriptionSegment], Error>

    var task: SFSpeechRecognitionTask?
    private var continuation: Continuation?
    private let lock = NSLock()

    init(continuation: Continuation) {
        self.continuation = continuation
    }

    func finish(_ result: Result<[SFTranscriptionSegment], Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        task?.finish()
        switch result {
        case .success(let segments):
            continuation.resume(returning: segments)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
