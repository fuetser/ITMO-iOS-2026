import Foundation
import Observation

@MainActor
@Observable
final class QuoteViewModel {
  private(set) var currentQuote: Quote?
  private(set) var isFavorite = false
  private(set) var isLoading = false
  private(set) var isSavingFavorite = false
  private(set) var loadFailureMessage: String?
  var errorMessage: String?

  private let repository: any QuoteRepositoryProtocol
  private let storage: any QuoteOfTheDayStorageProtocol
  private let favoritesService: any FavoritesServiceProtocol
  private var hasAttemptedInitialLoad = false
  // Номер запроса позволяет отбросить ответ, если после await уже начался новый запрос.
  private var favoriteStatusRequestID = 0

  init(
    repository: any QuoteRepositoryProtocol,
    storage: (any QuoteOfTheDayStorageProtocol)? = nil,
    favoritesService: any FavoritesServiceProtocol
  ) {
    self.repository = repository
    self.storage = storage ?? QuoteOfTheDayStorage()
    self.favoritesService = favoritesService
  }

  func loadInitialQuote() async {
    guard !isLoading else { return }
    if hasAttemptedInitialLoad {
      await refreshFavoriteStatus()
      return
    }
    if let saved = storage.load(), storage.isToday(saved.date) {
      currentQuote = saved.quote
      hasAttemptedInitialLoad = true
      await refreshFavoriteStatus()
    } else {
      await fetchNewQuote()
    }
  }

  func fetchNewQuote() async {
    guard !isLoading, !isSavingFavorite else { return }
    favoriteStatusRequestID += 1
    isLoading = true
    loadFailureMessage = nil
    errorMessage = nil
    defer { isLoading = false }

    do {
      let quote = try await repository.randomQuote()
      try Task.checkCancellation()
      currentQuote = quote
      isFavorite = false
      hasAttemptedInitialLoad = true
      saveQuoteForOfflineUse(quote)
    } catch {
      if Self.isCancellation(error) { return }
      hasAttemptedInitialLoad = true
      restoreSavedQuoteAfterLoadFailure(error)
    }
    await refreshFavoriteStatus()
  }

  func toggleFavorite() async {
    guard !isLoading, !isSavingFavorite, let quote = currentQuote else { return }
    favoriteStatusRequestID += 1
    isSavingFavorite = true
    defer { isSavingFavorite = false }
    do {
      // Список избранного мог изменить базу, поэтому проверяем её перед переключением.
      if try await favoritesService.isFavorite(quoteId: quote.id) {
        try await favoritesService.delete(quoteId: quote.id)
        isFavorite = false
      } else {
        try await favoritesService.add(quote)
        isFavorite = true
      }
    } catch {
      if !Self.isCancellation(error) {
        errorMessage = "Не удалось изменить избранное: \(error.localizedDescription)"
      }
    }
  }

  func refreshFavoriteStatus() async {
    guard !isSavingFavorite, let quote = currentQuote else { return }
    favoriteStatusRequestID += 1
    let requestID = favoriteStatusRequestID
    do {
      let status = try await favoritesService.isFavorite(quoteId: quote.id)
      // Пока мы ждали, пользователь мог сменить цитату или начать другой запрос.
      guard currentQuote?.id == quote.id else { return }
      guard requestID == favoriteStatusRequestID else { return }
      isFavorite = status
    } catch {
      guard !Self.isCancellation(error) else { return }
      guard currentQuote?.id == quote.id else { return }
      guard requestID == favoriteStatusRequestID else { return }
      // Ошибка проверки статуса не должна заменять более важное сообщение о загрузке.
      guard errorMessage == nil else { return }
      errorMessage = "Не удалось проверить избранное: \(error.localizedDescription)"
    }
  }

  private func saveQuoteForOfflineUse(_ quote: Quote) {
    do {
      try storage.save(quote: quote, date: .now)
    } catch {
      // Цитата уже загружена: оставляем её на экране, даже если локальная запись не удалась.
      errorMessage = "Цитата загружена, но не удалось сохранить её для работы без сети."
    }
  }

  private func restoreSavedQuoteAfterLoadFailure(_ error: any Error) {
    isFavorite = false
    if let saved = storage.load() {
      currentQuote = saved.quote
      errorMessage = "Не удалось загрузить цитаты. Показана сохранённая цитата."
    } else {
      currentQuote = nil
      if let networkError = error as? QuoteNetworkError {
        loadFailureMessage = networkError.userMessage + " Сохранённой цитаты нет."
      } else {
        loadFailureMessage = "Не удалось загрузить цитату. Сохранённой цитаты нет."
      }
    }
  }

  private static func isCancellation(_ error: any Error) -> Bool {
    // Отмена при закрытии экрана — ожидаемое событие, а не ошибка для пользователя.
    error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled
  }
}
