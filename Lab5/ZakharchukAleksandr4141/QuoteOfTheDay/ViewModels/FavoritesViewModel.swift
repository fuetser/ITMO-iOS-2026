import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var favorites: [FavoriteQuoteSnapshot] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let service: any FavoritesServiceProtocol

    init(service: any FavoritesServiceProtocol) {
        self.service = service
    }

    func load() async {
        guard !isLoading, !isSaving else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            favorites = try await service.fetchAll()
            hasLoaded = true
        } catch {
            report(error, prefix: "Не удалось загрузить избранное")
        }
    }

    func delete(quoteIds: [UUID]) async {
        await perform {
            for id in quoteIds { try await self.service.delete(quoteId: id) }
        }
    }

    func deleteAll() async {
        await perform { try await self.service.deleteAll() }
    }

    // Returning success lets the editor stay open when saving fails.
    func update(quoteId: UUID, note: String) async -> Bool {
        guard !isSaving, !isLoading else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.update(quoteId: quoteId, note: note)
        } catch {
            report(error, prefix: "Не удалось сохранить заметку")
            return false
        }
        await reloadAfterMutation()
        return true
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isSaving, !isLoading else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
            await reloadAfterMutation()
        } catch {
            // Keep the last successfully loaded list visible.
            report(error, prefix: "Не удалось изменить избранное")
        }
    }

    private func reloadAfterMutation() async {
        do {
            favorites = try await service.fetchAll()
            hasLoaded = true
        } catch {
            report(error, prefix: "Изменения сохранены, но не удалось обновить список")
        }
    }

    private func report(_ error: any Error, prefix: String) {
        guard !(error is CancellationError),
              (error as? URLError)?.code != .cancelled, !Task.isCancelled else { return }
        errorMessage = "\(prefix): \(error.localizedDescription)"
    }
}
