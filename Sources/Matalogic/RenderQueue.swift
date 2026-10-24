import Foundation
import SwiftUI

@MainActor
final class RenderQueueModel: ObservableObject {
    @Published private(set) var items: [RenderQueueItem]

    private let defaults: UserDefaults
    private let persistenceKey = "matalogic.renderQueue.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.loadItems(from: defaults, key: persistenceKey)
    }

    func render(
        projectID: UUID,
        shot: VideoShot,
        references: [VisualReference],
        provider: any VideoProvider
    ) async -> VideoTake {
        let take = VideoTake(provider: provider.name, status: .rendering)
        var queueItem = RenderQueueItem(
            projectID: projectID,
            shotID: shot.id,
            takeID: take.id,
            providerName: provider.name,
            status: .rendering
        )
        items.insert(queueItem, at: 0)
        persist()

        do {
            let request = VideoGenerationRequest(shot: shot, references: references)
            let result: VideoGenerationResult

            if let runway = provider as? RunwayVideoProvider {
                let jobID = try await runway.start(request)
                queueItem.providerJobID = jobID
                replace(queueItem)
                result = try await runway.resume(jobID: jobID)
            } else {
                result = try await provider.generate(request)
            }

            queueItem.status = .ready
            queueItem.providerJobID = result.providerJobID
            queueItem.outputURL = result.outputURL
            replace(queueItem)

            return VideoTake(
                id: take.id,
                provider: provider.name,
                providerJobID: result.providerJobID,
                outputURL: result.outputURL,
                status: .ready,
                createdAt: take.createdAt
            )
        } catch {
            queueItem.status = .failed
            queueItem.errorMessage = error.localizedDescription
            replace(queueItem)

            return VideoTake(
                id: take.id,
                provider: provider.name,
                providerJobID: queueItem.providerJobID,
                status: .failed,
                createdAt: take.createdAt,
                errorMessage: error.localizedDescription
            )
        }
    }

    func resumeInterruptedRunwayTasks() async {
        let provider = RunwayVideoProvider()
        guard let key = provider.apiKey, !key.isEmpty else { return }

        let resumable = items.filter {
            $0.providerName == provider.name &&
            $0.status == .rendering &&
            $0.providerJobID != nil
        }

        for item in resumable {
            guard let jobID = item.providerJobID else { continue }
            var updated = item
            do {
                let result = try await provider.resume(jobID: jobID)
                updated.status = .ready
                updated.outputURL = result.outputURL
                updated.errorMessage = nil
            } catch {
                updated.status = .failed
                updated.errorMessage = error.localizedDescription
            }
            replace(updated)
        }
    }

    func retryableItems() -> [RenderQueueItem] {
        items.filter { $0.status == .failed }
    }

    func clearFinished() {
        items.removeAll { $0.status == .ready }
        persist()
    }

    private func replace(_ updated: RenderQueueItem) {
        guard let index = items.firstIndex(where: { $0.id == updated.id }) else { return }
        items[index] = updated
        persist()
    }

    private func persist() {
        let payload = items.map(PersistedRenderQueueItem.init)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private static func loadItems(from defaults: UserDefaults, key: String) -> [RenderQueueItem] {
        guard
            let data = defaults.data(forKey: key),
            let payload = try? JSONDecoder().decode([PersistedRenderQueueItem].self, from: data)
        else { return [] }

        return payload.compactMap(\.queueItem)
    }
}

private struct PersistedRenderQueueItem: Codable {
    var id: UUID
    var projectID: UUID
    var shotID: UUID
    var takeID: UUID
    var providerName: String
    var status: String
    var providerJobID: String?
    var outputURL: URL?
    var errorMessage: String?

    init(_ item: RenderQueueItem) {
        id = item.id
        projectID = item.projectID
        shotID = item.shotID
        takeID = item.takeID
        providerName = item.providerName
        status = item.status.rawValue
        providerJobID = item.providerJobID
        outputURL = item.outputURL
        errorMessage = item.errorMessage
    }

    var queueItem: RenderQueueItem? {
        guard let status = RenderQueueItem.Status(rawValue: status) else { return nil }
        return RenderQueueItem(
            id: id,
            projectID: projectID,
            shotID: shotID,
            takeID: takeID,
            providerName: providerName,
            status: status,
            providerJobID: providerJobID,
            outputURL: outputURL,
            errorMessage: errorMessage
        )
    }
}
