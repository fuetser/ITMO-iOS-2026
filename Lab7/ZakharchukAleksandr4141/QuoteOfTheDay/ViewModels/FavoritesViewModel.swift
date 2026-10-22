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

  func loadFavorites() async {
    guard !isLoading, !isSaving else { return }
    errorMessage = nil
    isLoading = true
    defer { isLoading = false }
    do {
      favorites = try await service.fetchAll()
      hasLoaded = true
    } catch {
      showErrorUnlessCancelled(error, prefix: "Не удалось загрузить избранное")
    }
  }

  func delete(quoteIds: [UUID]) async {
    guard !isSaving, !isLoading else { return }
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }
    do {
      for quoteId in quoteIds {
        try await service.delete(quoteId: quoteId)
      }
      await reloadAfterMutation()
    } catch {
      // При ошибке оставляем последний успешно загруженный список на экране.
      showErrorUnlessCancelled(error, prefix: "Не удалось изменить избранное")
    }
  }

  func deleteAll() async {
    guard !isSaving, !isLoading else { return }
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }
    do {
      try await service.deleteAll()
      await reloadAfterMutation()
    } catch {
      showErrorUnlessCancelled(error, prefix: "Не удалось изменить избранное")
    }
  }

  // false оставляет редактор открытым. true означает, что сама заметка уже сохранена.
  func updateNote(quoteId: UUID, note: String) async -> Bool {
    guard !isSaving, !isLoading else { return false }
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }
    do {
      try await service.update(quoteId: quoteId, note: note)
    } catch {
      showErrorUnlessCancelled(error, prefix: "Не удалось сохранить заметку")
      return false
    }
    await reloadAfterMutation()
    return true
  }

  private func reloadAfterMutation() async {
    do {
      favorites = try await service.fetchAll()
      hasLoaded = true
    } catch {
      showErrorUnlessCancelled(error, prefix: "Изменения сохранены, но не удалось обновить список")
    }
  }

  private func showErrorUnlessCancelled(_ error: any Error, prefix: String) {
    guard !(error is CancellationError),
      (error as? URLError)?.code != .cancelled,
      !Task.isCancelled
    else { return }
    errorMessage = "\(prefix): \(error.localizedDescription)"
  }
}
