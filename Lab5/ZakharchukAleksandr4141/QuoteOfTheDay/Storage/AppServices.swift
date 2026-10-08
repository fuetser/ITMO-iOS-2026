import SwiftData

@MainActor
final class AppServices {
    private let container: ModelContainer
    private var favoritesTask: Task<FavoritesService, any Error>?

    init(container: ModelContainer) {
        self.container = container
    }

    func favorites() async throws -> FavoritesService {
        // Cache the task before awaiting so simultaneous windows share one actor.
        if let favoritesTask {
            return try await favoritesTask.value
        }
        let container = container
        let task = Task { try await FavoritesServiceFactory.make(container: container) }
        favoritesTask = task
        do {
            return try await task.value
        } catch {
            favoritesTask = nil
            throw error
        }
    }
}
