import Foundation
import SwiftUI

@MainActor
final class RenderQueueModel: ObservableObject {
    @Published private(set) var items: [RenderQueueItem] = []

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

        do {
            let result = try await provider.generate(
                VideoGenerationRequest(shot: shot, references: references)
            )
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
                status: .failed,
                createdAt: take.createdAt,
                errorMessage: error.localizedDescription
            )
        }
    }

    func retryableItems() -> [RenderQueueItem] {
        items.filter { $0.status == .failed }
    }

    private func replace(_ updated: RenderQueueItem) {
        guard let index = items.firstIndex(where: { $0.id == updated.id }) else { return }
        items[index] = updated
    }
}
