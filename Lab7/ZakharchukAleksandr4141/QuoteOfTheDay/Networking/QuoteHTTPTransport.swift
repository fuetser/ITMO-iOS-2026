import Foundation
import OSLog

nonisolated struct QuoteHTTPResponse: Sendable {
  let data: Data
  let response: HTTPURLResponse
}

nonisolated protocol QuoteHTTPTransport: Sendable {
  func send(_ request: URLRequest, attempt: Int) async throws -> QuoteHTTPResponse
}

// Конфигурация копируется при создании и больше не меняется.
nonisolated final class URLSessionQuoteTransport: QuoteHTTPTransport, @unchecked Sendable {
  private let configuration: URLSessionConfiguration
  private let logger = Logger(subsystem: "com.fuetser.QuoteOfTheDay", category: "HTTP")

  init(configuration: URLSessionConfiguration = .ephemeral) {
    // NSCopying для URLSessionConfiguration возвращает конфигурацию того же типа.
    let copy = configuration.copy() as! URLSessionConfiguration
    copy.timeoutIntervalForRequest = QuoteRequestRules.requestTimeout
    copy.timeoutIntervalForResource = QuoteRequestRules.totalTimeout
    copy.waitsForConnectivity = false
    copy.urlCache = nil
    copy.httpCookieStorage = nil
    copy.httpShouldSetCookies = false
    copy.urlCredentialStorage = nil
    self.configuration = copy
  }

  func send(_ request: URLRequest, attempt: Int) async throws -> QuoteHTTPResponse {
    let delegate = QuoteRequestDelegate(attempt: attempt)
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }

    return try await withTaskCancellationHandler {
      do {
        try Task.checkCancellation()
        return try await receiveResponse(request, session: session, delegate: delegate)
      } catch {
        try Task.checkCancellation()
        if delegate.hasRejectedRedirect { throw QuoteNetworkError.unsafeRedirect }
        throw error
      }
    } onCancel: {
      // Отмена должна прерывать и ожидание заголовков, и чтение тела ответа.
      session.invalidateAndCancel()
    }
  }

  private func receiveResponse(
    _ request: URLRequest,
    session: URLSession,
    delegate: QuoteRequestDelegate
  ) async throws -> QuoteHTTPResponse {
    let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
    try Task.checkCancellation()
    if delegate.hasRejectedRedirect { throw QuoteNetworkError.unsafeRedirect }
    guard let httpResponse = response as? HTTPURLResponse else {
      throw QuoteNetworkError.invalidResponse
    }
    logger.info("status=\(httpResponse.statusCode)")
    // Для HTTP-ошибки нужны только заголовки, включая Retry-After, но не тело.
    guard httpResponse.statusCode == 200 else {
      return QuoteHTTPResponse(data: Data(), response: httpResponse)
    }
    try validateHeaders(httpResponse)
    let data = try await readBody(bytes)
    return QuoteHTTPResponse(data: data, response: httpResponse)
  }

  private func validateHeaders(_ response: HTTPURLResponse) throws {
    let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
    let mediaType = contentType.split(separator: ";", maxSplits: 1).first.map { value in
      value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    } ?? ""
    guard mediaType == "application/json" else { throw QuoteNetworkError.invalidContentType }
    guard response.expectedContentLength <= Int64(QuoteRequestRules.maximumBytes) else {
      throw QuoteNetworkError.responseTooLarge
    }
  }

  private func readBody(_ bytes: URLSession.AsyncBytes) async throws -> Data {
    var data = Data()
    defer { logger.info("bytes=\(data.count)") }
    // Проверяем фактический размер по мере чтения, даже если Content-Length отсутствует.
    for try await byte in bytes {
      try Task.checkCancellation()
      guard data.count < QuoteRequestRules.maximumBytes else {
        throw QuoteNetworkError.responseTooLarge
      }
      data.append(byte)
    }
    return data
  }
}

// Приём данных выполняет AsyncBytes. Delegate нужен только для перенаправлений и метрик.
// NSLock защищает результат проверки перенаправления между callback и async-кодом.
nonisolated private final class QuoteRequestDelegate:
  NSObject, URLSessionTaskDelegate, @unchecked Sendable
{
  private let lock = NSLock()
  private var rejectedRedirect = false
  private let attempt: Int
  private let logger = Logger(subsystem: "com.fuetser.QuoteOfTheDay", category: "HTTP")

  init(attempt: Int) {
    self.attempt = attempt
  }

  var hasRejectedRedirect: Bool { lock.withLock { rejectedRedirect } }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    let redirectedRequest = allowedRedirect(request, originalURL: task.originalRequest?.url)
    if redirectedRequest == nil { lock.withLock { rejectedRedirect = true } }
    completionHandler(redirectedRequest)
  }

  private func allowedRedirect(_ request: URLRequest, originalURL: URL?) -> URLRequest? {
    guard let url = request.url,
      url.scheme?.lowercased() == "https",
      url.host?.lowercased() == originalURL?.host?.lowercased(),
      url.user == nil, url.password == nil,
      url.port == nil || url.port == 443
    else { return nil }
    var redirectedRequest = request
    redirectedRequest.httpMethod = "GET"
    redirectedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    return redirectedRequest
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    logger.debug("attempt=\(self.attempt) duration=\(metrics.taskInterval.duration)")
  }
}
