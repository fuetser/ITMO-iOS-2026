import SwiftData

// Хранит общие зависимости приложения: все окна используют один сервис избранного.
@MainActor
final class AppServices {
  let quoteRepository: any QuoteRepositoryProtocol
  private let container: ModelContainer
  private var favoritesTask: Task<FavoritesService, any Error>?

  init(
    container: ModelContainer,
    quoteRepository: any QuoteRepositoryProtocol = QuoteRepository()
  ) {
    self.container = container
    self.quoteRepository = quoteRepository
  }

  func favorites() async throws -> FavoritesService {
    // Запоминаем задачу до await: другое окно дождётся того же сервиса, а не создаст новый.
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
