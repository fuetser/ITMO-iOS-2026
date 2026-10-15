import Foundation

@testable import QuoteOfTheDay

nonisolated enum StubError: Error {
  case failed
}

// Управляемая остановка запроса: тест задаёт порядок ответов без sleep и реальной сети.
actor RequestGate {
  private var hasStarted = false
  private var isReleased = false
  private var startWaiter: CheckedContinuation<Void, Never>?
  private var responseWaiter: CheckedContinuation<Void, Never>?

  func pause() async {
    // Останавливаем только первый вызов; повторный запрос должен дойти до проверки счётчика.
    guard !hasStarted else { return }
    hasStarted = true
    startWaiter?.resume()
    startWaiter = nil
    guard !isReleased else { return }
    await withCheckedContinuation { continuation in
      responseWaiter = continuation
    }
  }

  func waitUntilStarted() async {
    guard !hasStarted else { return }
    await withCheckedContinuation { continuation in
      startWaiter = continuation
    }
  }

  func signal() {
    hasStarted = true
    startWaiter?.resume()
    startWaiter = nil
  }

  func release() {
    isReleased = true
    responseWaiter?.resume()
    responseWaiter = nil
  }
}

actor QuoteRepositoryStub: QuoteRepositoryProtocol {
  private var result: Result<Quote, any Error>
  private let gate: RequestGate?
  private(set) var requestCount = 0

  init(
    result: Result<Quote, any Error>,
    gate: RequestGate? = nil
  ) {
    self.result = result
    self.gate = gate
  }

  func setQuote(_ quote: Quote) {
    result = .success(quote)
  }

  func randomQuote() async throws -> Quote {
    requestCount += 1
    let response = result
    if let gate { await gate.pause() }
    return try response.get()
  }
}

@MainActor
final class QuoteStorageStub: QuoteOfTheDayStorageProtocol {
  var savedQuote: SavedQuote?
  var saveError: (any Error)?
  var considersDateToday = false

  init(savedQuote: SavedQuote? = nil, saveError: (any Error)? = nil) {
    self.savedQuote = savedQuote
    self.saveError = saveError
  }

  func save(quote: Quote, date: Date) throws {
    if let saveError { throw saveError }
    savedQuote = SavedQuote(quote: quote, date: date)
  }

  func load() -> SavedQuote? { savedQuote }

  func clear() { savedQuote = nil }

  func isToday(_ date: Date) -> Bool { considersDateToday }
}

actor FavoritesServiceStub: FavoritesServiceProtocol {
  private let fetchError: (any Error)?
  private let updateError: (any Error)?
  private let statusError: (any Error)?
  private var favoriteStatuses: [UUID: Bool] = [:]
  private var nextStatusGate: RequestGate?
  private var deleteGate: RequestGate?
  private(set) var updatedNotes: [UUID: String] = [:]
  private(set) var deleteCount = 0

  init(
    fetchError: (any Error)? = nil,
    updateError: (any Error)? = nil,
    statusError: (any Error)? = nil
  ) {
    self.fetchError = fetchError
    self.updateError = updateError
    self.statusError = statusError
  }

  func setFavorite(_ isFavorite: Bool, quoteId: UUID) {
    favoriteStatuses[quoteId] = isFavorite
  }

  func suspendNextStatusLookup(on gate: RequestGate) {
    nextStatusGate = gate
  }

  func suspendDeletion(on gate: RequestGate) {
    deleteGate = gate
  }

  func add(_ quote: Quote) async throws {
    favoriteStatuses[quote.id] = true
  }

  func fetchAll() async throws -> [FavoriteQuoteSnapshot] {
    if let fetchError { throw fetchError }
    return []
  }

  func isFavorite(quoteId: UUID) async throws -> Bool {
    let status = favoriteStatuses[quoteId] ?? false
    let gate = nextStatusGate
    nextStatusGate = nil
    if let gate { await gate.pause() }
    if let statusError { throw statusError }
    return status
  }

  func update(quoteId: UUID, note: String) async throws {
    if let updateError { throw updateError }
    updatedNotes[quoteId] = note
  }

  func delete(quoteId: UUID) async throws {
    deleteCount += 1
    if let deleteGate { await deleteGate.pause() }
    favoriteStatuses[quoteId] = false
  }

  func deleteAll() async throws {
    deleteCount += 1
    if let deleteGate { await deleteGate.pause() }
    favoriteStatuses.removeAll()
  }
}
