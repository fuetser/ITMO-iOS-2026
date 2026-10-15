import Foundation
import Testing

@testable import QuoteOfTheDay

@Suite(.serialized)
@MainActor
struct QuoteRepositoryTests {
  @Test
  func everyCallMakesARequestAndRepeatedQuotesAreAllowed() async throws {
    StubURLProtocol.state.configure(Array(repeating: .ok, count: 10))
    let repository = makeRepository()
    var identifiers: [UUID] = []
    for _ in 0..<10 {
      identifiers.append(try await repository.randomQuote().id)
    }
    #expect(StubURLProtocol.state.recordedRequests.count == 10)
    #expect(Set(identifiers).count == 1)
  }

  @Test
  func cancellingOneRequestDoesNotAffectAnother() async throws {
    let gate = RequestGate()
    let stopped = RequestGate()
    StubURLProtocol.state.configure([.held(gate), .ok], stopSignal: stopped)
    let repository = makeRepository()
    let first = Task { try await repository.randomQuote() }
    await gate.waitUntilStarted()

    // Второй запрос завершается, пока первый всё ещё ожидает ответ сервера.
    let second = try await repository.randomQuote()
    #expect(second.text == "One")
    first.cancel()
    do {
      _ = try await first.value
      Issue.record("Expected cancellation")
    } catch {
      #expect(error is CancellationError)
    }
    await stopped.waitUntilStarted()
    await gate.release()
    #expect(StubURLProtocol.state.recordedRequests.count == 2)
  }

  private func makeRepository(
    timing: QuoteNetworkTiming = QuoteNetworkTiming()
  ) -> QuoteRepository {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return QuoteRepository(
      transport: URLSessionQuoteTransport(configuration: configuration),
      timing: timing
    )
  }

  private func expectFailure(
    _ expected: QuoteNetworkError,
    repository: QuoteRepository
  ) async {
    do {
      _ = try await repository.randomQuote()
      Issue.record("Expected a network error")
    } catch {
      #expect(error as? QuoteNetworkError == expected)
    }
  }

  @Test
  func validResponseAndStableIdentifier() async throws {
    StubURLProtocol.state.configure([
      .response(200, ["Content-Type": "application/json; charset=utf-8"], [StubHTTPReply.body]),
    ])
    let quote = try await makeRepository().randomQuote()
    #expect(quote.text == "One")
    #expect(quote.id.uuidString == "D00D0000-0000-4000-8000-000000000001")
    let request = try #require(StubURLProtocol.state.recordedRequests.first)
    #expect(request.url == QuoteRequestRules.endpoint)
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(request.timeoutInterval == 10)
  }

  @Test(arguments: ["text/html", "", "application/xml"])
  func rejectsUnexpectedContentType(_ type: String) async {
    StubURLProtocol.state.configure([.response(200, ["Content-Type": type], [StubHTTPReply.body])])
    await expectFailure(.invalidContentType, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: ["", "{broken", "{}", #"{"quotes":"wrong"}"#])
  func malformedJSONIsNotRetried(_ body: String) async {
    StubURLProtocol.state.configure([
      .response(200, ["Content-Type": "application/json"], [Data(body.utf8)]),
    ])
    await expectFailure(.invalidFormat, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: [
    #"{"id":0,"quote":"One","author":"Author"}"#,
    #"{"id":281474976710656,"quote":"One","author":"Author"}"#,
    #"{"id":1,"quote":" ","author":"Author"}"#,
    #"{"id":1,"quote":"One","author":" "}"#,
  ])
  func invalidQuoteIsNotRetried(_ body: String) async {
    StubURLProtocol.state.configure([
      .response(200, ["Content-Type": "application/json"], [Data(body.utf8)]),
    ])
    await expectFailure(.invalidQuote, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: [true, false])
  func responseLimitIsEnforcedWithAndWithoutLength(_ declaresLength: Bool) async {
    var headers = ["Content-Type": "application/json"]
    if declaresLength { headers["Content-Length"] = String(QuoteRequestRules.maximumBytes + 1) }
    let chunks = [Data(repeating: 32, count: QuoteRequestRules.maximumBytes), Data([32])]
    StubURLProtocol.state.configure([.response(200, headers, chunks)])
    await expectFailure(.responseTooLarge, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test
  func responseExactlyAtLimitIsAccepted() async throws {
    var body = StubHTTPReply.body
    body.append(Data(repeating: 32, count: QuoteRequestRules.maximumBytes - body.count))
    StubURLProtocol.state.configure([
      .response(200, ["Content-Type": "application/json"], [body]),
    ])
    let quote = try await makeRepository().randomQuote()
    #expect(quote.text == "One")
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: [408, 429, 500, 502, 503, 504])
  func transientHTTPFailureIsRetried(_ status: Int) async throws {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure([.response(status, [:], []), .ok])
    _ = try await makeRepository(timing: clock.timing()).randomQuote()
    #expect(StubURLProtocol.state.recordedRequests.count == 2)
    #expect(clock.delays == [0.5])
  }

  @Test(arguments: [201, 204, 400, 401, 403, 404, 501])
  func otherHTTPStatusesAreNotRetried(_ status: Int) async {
    StubURLProtocol.state.configure([.response(status, [:], [])])
    await expectFailure(.httpStatus(status, retryAfter: nil), repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: [URLError.Code.timedOut, .networkConnectionLost])
  func transientTransportFailureIsRetried(_ code: URLError.Code) async throws {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure([.failure(code), .ok])
    _ = try await makeRepository(timing: clock.timing()).randomQuote()
    #expect(StubURLProtocol.state.recordedRequests.count == 2)
  }

  @Test(arguments: [URLError.Code.serverCertificateUntrusted, .notConnectedToInternet])
  func permanentTransportFailureIsNotRetried(_ code: URLError.Code) async {
    StubURLProtocol.state.configure([.failure(code)])
    let expected: QuoteNetworkError =
      code == .notConnectedToInternet ? .offline : .transport(code.rawValue)
    await expectFailure(expected, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test
  func retriesAreLimitedToThreeAttempts() async {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure(Array(repeating: .response(503, [:], []), count: 3))
    await expectFailure(
      .httpStatus(503, retryAfter: nil),
      repository: makeRepository(timing: clock.timing())
    )
    #expect(StubURLProtocol.state.recordedRequests.count == 3)
    #expect(clock.delays == [0.5, 1])
  }

  @Test(arguments: ["3", "Tue, 14 Nov 2023 22:13:23 GMT"])
  func retryAfterSecondsAndHTTPDateAreRespected(_ header: String) async throws {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure([.response(429, ["Retry-After": header], []), .ok])
    _ = try await makeRepository(timing: clock.timing()).randomQuote()
    #expect(clock.delays == [3])
  }

  @Test
  func retryAfterOutsideBudgetDoesNotStartAnotherAttempt() async {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure([.response(429, ["Retry-After": "120"], [])])
    await expectFailure(
      .rateLimited(until: clock.now.addingTimeInterval(120)),
      repository: makeRepository(timing: clock.timing())
    )
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
    #expect(clock.delays.isEmpty)
  }

  @Test
  func malformedRetryAfterUsesNormalBackoff() async throws {
    let clock = TestNetworkTime()
    StubURLProtocol.state.configure([.response(429, ["Retry-After": "not-a-date"], []), .ok])
    _ = try await makeRepository(timing: clock.timing()).randomQuote()
    #expect(clock.delays == [0.5])
  }

  @Test
  func elapsedBudgetStopsRetries() async {
    let clock = TestNetworkTime()
    var timing = clock.timing()
    timing.sleep = { _ in clock.advance(20) }
    StubURLProtocol.state.configure([.response(503, [:], []), .ok])
    await expectFailure(.timeout, repository: makeRepository(timing: timing))
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test
  func watchdogCancelsAnUnresponsiveTransport() async {
    let requestGate = RequestGate()
    let deadlineGate = RequestGate()
    let stopped = RequestGate()
    StubURLProtocol.state.configure([.held(requestGate)], stopSignal: stopped)
    var timing = QuoteNetworkTiming()
    timing.deadlineSleep = { _ in
      await deadlineGate.pause()
      try Task.checkCancellation()
    }
    let repository = makeRepository(timing: timing)
    let load = Task { try await repository.randomQuote() }
    await requestGate.waitUntilStarted()
    await deadlineGate.release()
    do {
      _ = try await load.value
      Issue.record("Expected timeout")
    } catch {
      #expect(error as? QuoteNetworkError == .timeout)
    }
    await stopped.waitUntilStarted()
    await requestGate.release()
  }

  @Test
  func cancellingLoadStopsURLSessionTask() async {
    let gate = RequestGate()
    let stopped = RequestGate()
    StubURLProtocol.state.configure([.held(gate)], stopSignal: stopped)
    let repository = makeRepository()
    let load = Task { try await repository.randomQuote() }
    await gate.waitUntilStarted()
    load.cancel()
    do {
      _ = try await load.value
      Issue.record("Expected cancellation")
    } catch {
      #expect(error is CancellationError)
    }
    await stopped.waitUntilStarted()
    await gate.release()
  }

  @Test
  func cancellingWhileReadingBodyStopsURLSessionTask() async {
    let gate = RequestGate()
    let stopped = RequestGate()
    StubURLProtocol.state.configure([.streaming(gate)], stopSignal: stopped)
    let repository = makeRepository()
    let load = Task { try await repository.randomQuote() }
    await gate.waitUntilStarted()
    load.cancel()
    do {
      _ = try await load.value
      Issue.record("Expected cancellation")
    } catch {
      #expect(error is CancellationError)
    }
    await stopped.waitUntilStarted()
    await gate.release()
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test
  func cancellingDuringBackoffDoesNotRetry() async {
    let retryGate = RequestGate()
    var timing = QuoteNetworkTiming()
    timing.sleep = { _ in
      await retryGate.signal()
      // В нормальном тесте ожидание сразу прерывается отменой, а не истечением 30 секунд.
      try await QuoteNetworkTiming.liveSleep(30)
    }
    StubURLProtocol.state.configure([.response(503, [:], []), .ok])
    let repository = makeRepository(timing: timing)
    let load = Task { try await repository.randomQuote() }
    await retryGate.waitUntilStarted()
    load.cancel()
    do {
      _ = try await load.value
      Issue.record("Expected cancellation")
    } catch {
      #expect(error is CancellationError)
    }
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test(arguments: ["http://dummyjson.com/quotes", "https://example.com/quotes"])
  func unsafeRedirectIsRejected(_ location: String) async throws {
    let url = try #require(URL(string: location))
    StubURLProtocol.state.configure([.redirect(url)])
    await expectFailure(.unsafeRedirect, repository: makeRepository())
    #expect(StubURLProtocol.state.recordedRequests.count == 1)
  }

  @Test
  func sameHostHTTPSRedirectIsAllowed() async throws {
    let url = try #require(URL(string: "https://dummyjson.com/another-quote"))
    StubURLProtocol.state.configure([.redirect(url), .ok])
    let quote = try await makeRepository().randomQuote()
    #expect(quote.text == "One")
    #expect(StubURLProtocol.state.recordedRequests.count == 2)
    #expect(
      StubURLProtocol.state.recordedRequests.last?.value(forHTTPHeaderField: "Accept")
        == "application/json"
    )
  }
}
