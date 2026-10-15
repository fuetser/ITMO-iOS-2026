import Foundation
import Testing

@testable import QuoteOfTheDay

@MainActor
struct QuoteViewModelTests {
  private let quote = Quote(text: "A test quote", author: "Author")

  @Test
  func networkErrorHasUserFacingMessageWithoutTechnicalDetails() async {
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .failure(QuoteNetworkError.offline)),
      storage: QuoteStorageStub(),
      favoritesService: FavoritesServiceStub()
    )
    await model.fetchNewQuote()
    #expect(model.loadFailureMessage == "Нет подключения к интернету. Сохранённой цитаты нет.")
    #expect(model.errorMessage == nil)
  }

  @Test
  func loadedQuoteIsDisplayedAndSaved() async {
    let storage = QuoteStorageStub()
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .success(quote)),
      storage: storage,
      favoritesService: FavoritesServiceStub()
    )

    await model.loadInitialQuote()

    #expect(model.currentQuote == quote)
    #expect(storage.savedQuote?.quote == quote)
    #expect(model.errorMessage == nil)
    #expect(!model.isLoading)
  }

  @Test
  func todaysSavedQuoteDoesNotNeedNetwork() async {
    let storage = QuoteStorageStub(savedQuote: SavedQuote(quote: quote, date: .now))
    storage.considersDateToday = true
    let repository = QuoteRepositoryStub(result: .failure(StubError.failed))
    let model = QuoteViewModel(
      repository: repository,
      storage: storage,
      favoritesService: FavoritesServiceStub()
    )

    await model.loadInitialQuote()

    let requestCount = await repository.requestCount
    #expect(requestCount == 0)
    #expect(model.currentQuote == quote)
    #expect(model.errorMessage == nil)
  }

  @Test
  func networkFailureRestoresSavedQuote() async {
    let storage = QuoteStorageStub(savedQuote: SavedQuote(quote: quote, date: .distantPast))
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .failure(URLError(.notConnectedToInternet))),
      storage: storage,
      favoritesService: FavoritesServiceStub()
    )

    await model.loadInitialQuote()

    #expect(model.currentQuote == quote)
    #expect(model.errorMessage == "Не удалось загрузить цитаты. Показана сохранённая цитата.")
    #expect(model.loadFailureMessage == nil)
    #expect(!model.isLoading)
  }

  @Test
  func networkFailureWithoutSavedQuoteShowsEmptyState() async {
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .failure(StubError.failed)),
      storage: QuoteStorageStub(),
      favoritesService: FavoritesServiceStub()
    )

    await model.loadInitialQuote()

    #expect(model.currentQuote == nil)
    #expect(model.loadFailureMessage == "Не удалось загрузить цитату. Сохранённой цитаты нет.")
    #expect(model.errorMessage == nil)
  }

  @Test
  func saveFailureKeepsLoadedQuoteVisible() async {
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .success(quote)),
      storage: QuoteStorageStub(saveError: StubError.failed),
      favoritesService: FavoritesServiceStub()
    )

    await model.fetchNewQuote()

    #expect(model.currentQuote == quote)
    let expectedMessage = "Цитата загружена, но не удалось сохранить её для работы без сети."
    #expect(model.errorMessage == expectedMessage)
    #expect(model.loadFailureMessage == nil)
    #expect(!model.isLoading)
  }

  @Test
  func cancellationDoesNotShowError() async {
    let repository = QuoteRepositoryStub(result: .failure(CancellationError()))
    let model = QuoteViewModel(
      repository: repository,
      storage: QuoteStorageStub(),
      favoritesService: FavoritesServiceStub()
    )

    await model.fetchNewQuote()

    #expect(model.currentQuote == nil)
    #expect(model.errorMessage == nil)
    #expect(model.loadFailureMessage == nil)
    #expect(!model.isLoading)

    // После отмены первое появление экрана должно снова попытаться загрузить цитату.
    await repository.setQuote(quote)
    await model.loadInitialQuote()
    #expect(model.currentQuote == quote)
  }

  @Test
  func statusFailureDoesNotReplaceSaveWarning() async {
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .success(quote)),
      storage: QuoteStorageStub(saveError: StubError.failed),
      favoritesService: FavoritesServiceStub(statusError: StubError.failed)
    )

    await model.fetchNewQuote()

    #expect(model.currentQuote == quote)
    let expectedMessage = "Цитата загружена, но не удалось сохранить её для работы без сети."
    #expect(model.errorMessage == expectedMessage)
  }

  @Test
  func repeatedLoadIsIgnoredWhileRequestIsRunning() async {
    let gate = RequestGate()
    let repository = QuoteRepositoryStub(result: .success(quote), gate: gate)
    let model = QuoteViewModel(
      repository: repository,
      storage: QuoteStorageStub(),
      favoritesService: FavoritesServiceStub()
    )

    let firstLoad = Task { await model.fetchNewQuote() }
    await gate.waitUntilStarted()
    await model.fetchNewQuote()

    let requestCount = await repository.requestCount
    #expect(requestCount == 1)
    #expect(model.isLoading)
    await gate.release()
    await firstLoad.value
    #expect(model.currentQuote == quote)
    #expect(!model.isLoading)
  }

  @Test
  func cancelledTaskDoesNotDisplayOrSaveResponse() async {
    let gate = RequestGate()
    let storage = QuoteStorageStub()
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .success(quote), gate: gate),
      storage: storage,
      favoritesService: FavoritesServiceStub()
    )

    let load = Task { await model.fetchNewQuote() }
    await gate.waitUntilStarted()
    load.cancel()
    await gate.release()
    await load.value

    #expect(model.currentQuote == nil)
    #expect(storage.savedQuote == nil)
    #expect(model.errorMessage == nil)
    #expect(!model.isLoading)
  }

  @Test
  func olderStatusResponseDoesNotOverwriteNewerLookupForSameQuote() async {
    let service = FavoritesServiceStub()
    let model = QuoteViewModel(
      repository: QuoteRepositoryStub(result: .success(quote)),
      storage: QuoteStorageStub(),
      favoritesService: service
    )
    await model.fetchNewQuote()
    await service.setFavorite(true, quoteId: quote.id)
    let gate = RequestGate()
    await service.suspendNextStatusLookup(on: gate)

    let oldLookup = Task { await model.refreshFavoriteStatus() }
    await gate.waitUntilStarted()
    await service.setFavorite(false, quoteId: quote.id)
    await model.refreshFavoriteStatus()
    await gate.release()
    await oldLookup.value

    #expect(!model.isFavorite)
  }

  @Test
  func statusForPreviousQuoteDoesNotChangeNewQuote() async {
    let service = FavoritesServiceStub()
    let repository = QuoteRepositoryStub(result: .success(quote))
    let model = QuoteViewModel(
      repository: repository,
      storage: QuoteStorageStub(),
      favoritesService: service
    )
    await model.fetchNewQuote()
    await service.setFavorite(true, quoteId: quote.id)
    let gate = RequestGate()
    await service.suspendNextStatusLookup(on: gate)

    let oldLookup = Task { await model.refreshFavoriteStatus() }
    await gate.waitUntilStarted()
    let nextQuote = Quote(text: "Another quote", author: "Another author")
    await repository.setQuote(nextQuote)
    await model.fetchNewQuote()
    await gate.release()
    await oldLookup.value

    #expect(model.currentQuote == nextQuote)
    #expect(!model.isFavorite)
  }
}
