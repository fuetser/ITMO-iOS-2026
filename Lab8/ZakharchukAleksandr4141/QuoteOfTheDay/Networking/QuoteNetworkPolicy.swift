import Foundation

nonisolated enum QuoteNetworkError: Error, Equatable {
  case offline
  case timeout
  case rateLimited(until: Date?)
  case httpStatus(Int, retryAfter: Date?)
  case invalidResponse
  case invalidContentType
  case invalidFormat
  case responseTooLarge
  case invalidQuote
  case unsafeRedirect
  case transport(Int)

  var retryAfter: Date? {
    switch self {
    case .rateLimited(let date), .httpStatus(_, let date): date
    default: nil
    }
  }

  var userMessage: String {
    switch self {
    case .offline: "Нет подключения к интернету."
    case .timeout: "Сервер не ответил вовремя. Попробуйте позже."
    case .rateLimited: "Слишком много запросов. Попробуйте позже."
    case .httpStatus: "Сервис цитат временно недоступен."
    case .transport: "Не удалось подключиться к сервису цитат."
    default: "Сервис вернул некорректную цитату."
    }
  }

  var category: String {
    switch self {
    case .offline: "offline"
    case .timeout: "timeout"
    case .rateLimited: "rateLimited"
    case .httpStatus: "httpStatus"
    case .invalidResponse: "invalidResponse"
    case .invalidContentType: "invalidContentType"
    case .invalidFormat: "invalidFormat"
    case .responseTooLarge: "responseTooLarge"
    case .invalidQuote: "invalidQuote"
    case .unsafeRedirect: "unsafeRedirect"
    case .transport: "transport"
    }
  }
}

// Настройки времени внедряются отдельно: тесты повторов не должны ждать реальные секунды.
nonisolated struct QuoteNetworkTiming: Sendable {
  var now: @Sendable () -> Date = { Date() }
  var uptime: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  var sleep: @Sendable (TimeInterval) async throws -> Void = QuoteNetworkTiming.liveSleep
  var deadlineSleep: @Sendable (TimeInterval) async throws -> Void = QuoteNetworkTiming.liveSleep
  var jitter: @Sendable (TimeInterval) -> TimeInterval = { Double.random(in: 0...$0) }

  static func liveSleep(_ seconds: TimeInterval) async throws {
    try await Task.sleep(for: .seconds(seconds))
  }
}

nonisolated enum QuoteRequestRules {
  static let maximumBytes = 64 * 1024
  static let maximumAttempts = 3
  static let requestTimeout: TimeInterval = 10
  static let totalTimeout: TimeInterval = 20
  // URL задан в коде и проверен; пользовательский ввод сюда не попадает.
  static let endpoint = URL(string: "https://dummyjson.com/quotes/random")!
}

// Разбор HTTP-заголовка отделён от сценария получения цитаты.
nonisolated enum RetryAfterParser {
  static func date(from header: String?, now: Date) -> Date? {
    guard let header else { return nil }
    let value = header.trimmingCharacters(in: .whitespacesAndNewlines)
    return dateFromSeconds(value, now: now) ?? dateFromHTTPDate(value)
  }

  private static func dateFromSeconds(_ value: String, now: Date) -> Date? {
    guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }),
      let seconds = Double(value), seconds.isFinite
    else { return nil }
    return now.addingTimeInterval(seconds)
  }

  private static func dateFromHTTPDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.isLenient = false
    for format in [
      "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
      "EEEE, dd-MMM-yy HH:mm:ss 'GMT'",
      "EEE MMM d HH:mm:ss yyyy",
    ] {
      formatter.dateFormat = format
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }
}
