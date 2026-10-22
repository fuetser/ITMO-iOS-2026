import Foundation
import OSLog

nonisolated protocol QuoteRepositoryProtocol: Sendable {
  func randomQuote() async throws -> Quote
}

nonisolated final class QuoteRepository: QuoteRepositoryProtocol, Sendable {
  private let transport: any QuoteHTTPTransport
  private let timing: QuoteNetworkTiming
  private let logger = Logger(subsystem: "com.fuetser.QuoteOfTheDay", category: "QuoteRepository")

  init(
    transport: any QuoteHTTPTransport = URLSessionQuoteTransport(),
    timing: QuoteNetworkTiming = QuoteNetworkTiming()
  ) {
    self.transport = transport
    self.timing = timing
  }

  @concurrent
  func randomQuote() async throws -> Quote {
    try await withThrowingTaskGroup(of: Quote.self) { group in
      group.addTask { try await self.loadWithRetries() }
      group.addTask { try await self.failWhenDeadlineExpires() }
      defer { group.cancelAll() }
      guard let quote = try await group.next() else { throw CancellationError() }
      try Task.checkCancellation()
      return quote
    }
  }

  private func loadWithRetries() async throws -> Quote {
    let startedAt = timing.uptime()
    for attempt in 1...QuoteRequestRules.maximumAttempts {
      try checkRequestBudget(since: startedAt)
      do {
        let quote = try await loadQuote(attempt: attempt)
        try checkRequestBudget(since: startedAt)
        return quote
      } catch {
        let failure = try reportFailure(error, attempt: attempt)
        try await waitBeforeRetry(failure, attempt: attempt, startedAt: startedAt)
      }
    }
    throw QuoteNetworkError.timeout
  }

  private func failWhenDeadlineExpires() async throws -> Quote {
    try await timing.deadlineSleep(QuoteRequestRules.totalTimeout)
    throw QuoteNetworkError.timeout
  }

  private func checkRequestBudget(since startedAt: TimeInterval) throws {
    try Task.checkCancellation()
    guard timing.uptime() - startedAt < QuoteRequestRules.totalTimeout else {
      throw QuoteNetworkError.timeout
    }
  }

  private func loadQuote(attempt: Int) async throws -> Quote {
    let payload = try await transport.send(makeRequest(), attempt: attempt)
    try Task.checkCancellation()
    try validateStatus(payload.response)
    return try decode(payload.data)
  }

  private func makeRequest() -> URLRequest {
    var request = URLRequest(url: QuoteRequestRules.endpoint)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = QuoteRequestRules.requestTimeout
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }

  private func validateStatus(_ response: HTTPURLResponse) throws {
    let status = response.statusCode
    guard status != 200 else { return }
    let retryDate = RetryAfterParser.date(
      from: response.value(forHTTPHeaderField: "Retry-After"),
      now: timing.now()
    )
    if status == 429 { throw QuoteNetworkError.rateLimited(until: retryDate) }
    throw QuoteNetworkError.httpStatus(status, retryAfter: retryDate)
  }

  private func reportFailure(_ error: any Error, attempt: Int) throws -> QuoteNetworkError {
    if error is CancellationError || (error as? URLError)?.code == .cancelled {
      throw CancellationError()
    }
    try Task.checkCancellation()
    let failure = classify(error)
    logger.error("attempt=\(attempt) category=\(failure.category, privacy: .public)")
    return failure
  }

  private func waitBeforeRetry(
    _ failure: QuoteNetworkError,
    attempt: Int,
    startedAt: TimeInterval
  ) async throws {
    guard attempt < QuoteRequestRules.maximumAttempts, shouldRetry(failure) else { throw failure }
    let delay = retryDelay(for: failure, attempt: attempt)
    let remaining = QuoteRequestRules.totalTimeout - (timing.uptime() - startedAt)
    // Никогда не сокращаем Retry-After, чтобы уложиться в наш локальный бюджет.
    guard delay < remaining else { throw failure }
    try await timing.sleep(delay)
  }

  private func retryDelay(for failure: QuoteNetworkError, attempt: Int) -> TimeInterval {
    let randomDelay = timing.jitter(attempt == 1 ? 0.5 : 1)
    let serverDelay = max(0, failure.retryAfter?.timeIntervalSince(timing.now()) ?? 0)
    return max(randomDelay, serverDelay)
  }

  private func decode(_ data: Data) throws -> Quote {
    guard data.count <= QuoteRequestRules.maximumBytes else {
      throw QuoteNetworkError.responseTooLarge
    }
    let response: APIQuote
    do {
      response = try JSONDecoder().decode(APIQuote.self, from: data)
    } catch {
      throw QuoteNetworkError.invalidFormat
    }
    return try response.asQuote()
  }

  private func shouldRetry(_ error: QuoteNetworkError) -> Bool {
    switch error {
    case .timeout, .rateLimited: true
    case .httpStatus(let status, _): [408, 500, 502, 503, 504].contains(status)
    case .transport(let code): code == URLError.Code.networkConnectionLost.rawValue
    default: false
    }
  }

  private func classify(_ error: any Error) -> QuoteNetworkError {
    if let failure = error as? QuoteNetworkError { return failure }
    guard let error = error as? URLError else { return .invalidResponse }
    switch error.code {
    case .notConnectedToInternet: return .offline
    case .timedOut: return .timeout
    default: return .transport(error.code.rawValue)
    }
  }
}

nonisolated private struct APIQuote: Decodable {
  let id: Int64
  let quote: String
  let author: String

  func asQuote() throws -> Quote {
    guard id > 0, id <= 0xFFFFFFFFFFFF,
      !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw QuoteNetworkError.invalidQuote }
    // Сохраняем прежнее соответствие серверного ID и UUID для связи с избранным.
    let suffix = String(format: "%012llX", id)
    guard let uuid = UUID(uuidString: "D00D0000-0000-4000-8000-\(suffix)") else {
      throw QuoteNetworkError.invalidQuote
    }
    return Quote(id: uuid, text: quote, author: author)
  }
}
