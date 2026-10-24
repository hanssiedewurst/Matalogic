import Foundation

struct RunwayVideoProvider: VideoProvider {
    enum ProviderError: LocalizedError {
        case missingAPIKey
        case missingReferenceImage
        case referenceTooLarge
        case invalidResponse
        case requestFailed(String)
        case taskFailed(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Runway API key missing. Set RUNWAYML_API_SECRET before starting Matalogic."
            case .missingReferenceImage:
                return "This Runway image-to-video render needs at least one local reference image."
            case .referenceTooLarge:
                return "The selected reference image is larger than the 5 MB data-URI limit."
            case .invalidResponse:
                return "Runway returned an unreadable response."
            case .requestFailed(let message):
                return "Runway request failed: \(message)"
            case .taskFailed(let message):
                return "Runway render failed: \(message)"
            case .timedOut:
                return "Runway render timed out while waiting for the task."
            }
        }
    }

    let name = "Runway"
    var model: String = "gen4.5"
    var apiKey: String?
    var session: URLSession = .shared

    init(
        model: String = "gen4.5",
        apiKey: String? = ProcessInfo.processInfo.environment["RUNWAYML_API_SECRET"],
        session: URLSession = .shared
    ) {
        self.model = model
        self.apiKey = apiKey
        self.session = session
    }

    func generate(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult {
        let taskID = try await start(request)
        return try await resume(jobID: taskID)
    }

    func start(_ request: VideoGenerationRequest) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingAPIKey }
        guard let imageURL = request.references.compactMap(\.fileURL).first else {
            throw ProviderError.missingReferenceImage
        }

        let promptImage = try makeDataURI(for: imageURL)
        return try await createTask(
            apiKey: apiKey,
            promptImage: promptImage,
            promptText: request.shot.prompt,
            ratio: runwayRatio(for: request.aspectRatio),
            duration: normalizedDuration(request.shot.duration)
        )
    }

    func resume(jobID: String) async throws -> VideoGenerationResult {
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingAPIKey }
        return try await waitForTask(id: jobID, apiKey: apiKey)
    }

    private func createTask(
        apiKey: String,
        promptImage: String,
        promptText: String,
        ratio: String,
        duration: Int
    ) async throws -> String {
        let url = URL(string: "https://api.dev.runwayml.com/v1/image_to_video")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("2024-11-06", forHTTPHeaderField: "X-Runway-Version")

        let payload = CreateTaskRequest(
            model: model,
            promptImage: promptImage,
            promptText: promptText,
            ratio: ratio,
            duration: duration
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(CreateTaskResponse.self, from: data) else {
            throw ProviderError.invalidResponse
        }
        return decoded.id
    }

    private func waitForTask(id: String, apiKey: String) async throws -> VideoGenerationResult {
        let url = URL(string: "https://api.dev.runwayml.com/v1/tasks/\(id)")!

        for _ in 0..<120 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("2024-11-06", forHTTPHeaderField: "X-Runway-Version")

            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            guard let task = try? JSONDecoder().decode(TaskResponse.self, from: data) else {
                throw ProviderError.invalidResponse
            }

            switch task.status.uppercased() {
            case "SUCCEEDED":
                return VideoGenerationResult(
                    providerJobID: id,
                    outputURL: task.output?.first.flatMap(URL.init(string:))
                )
            case "FAILED", "CANCELED", "CANCELLED":
                throw ProviderError.taskFailed(task.failure ?? task.status)
            default:
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        throw ProviderError.timedOut
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ProviderError.requestFailed(message)
        }
    }

    private func makeDataURI(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard data.count <= 5 * 1024 * 1024 else { throw ProviderError.referenceTooLarge }

        let mime: String
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": mime = "image/jpeg"
        case "webp": mime = "image/webp"
        default: mime = "image/png"
        }

        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    private func runwayRatio(for aspectRatio: String) -> String {
        switch aspectRatio {
        case "9:16": return "720:1280"
        case "1:1": return "960:960"
        default: return "1280:720"
        }
    }

    private func normalizedDuration(_ duration: TimeInterval) -> Int {
        max(5, min(10, Int(duration.rounded())))
    }
}

private struct CreateTaskRequest: Encodable {
    var model: String
    var promptImage: String
    var promptText: String
    var ratio: String
    var duration: Int
}

private struct CreateTaskResponse: Decodable {
    var id: String
}

private struct TaskResponse: Decodable {
    var id: String
    var status: String
    var output: [String]?
    var failure: String?
}
