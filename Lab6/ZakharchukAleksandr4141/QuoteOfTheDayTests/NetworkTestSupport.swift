import Foundation

@testable import QuoteOfTheDay

nonisolated enum StubHTTPReply: Sendable {
  case response(Int, [String: String], [Data])
  case failure(URLError.Code)
  case held(RequestGate)
  case streaming(RequestGate)
  case redirect(URL)

  static let body = Data(#"{"id":1,"quote":"One","author":"Author"}"#.utf8)
  static let ok = StubHTTPReply.response(200, ["Content-Type": "application/json"], [body])
}

// Все HTTP-тесты входят в одну serialized suite: общий реестр не пересекается между тестами.
nonisolated final class StubHTTPState: @unchecked Sendable {
  private let lock = NSLock()
  private var replies: [StubHTTPReply] = []
  private var requests: [URLRequest] = []
  private var stopSignal: RequestGate?

  func configure(_ replies: [StubHTTPReply], stopSignal: RequestGate? = nil) {
    lock.withLock {
      self.replies = replies
      requests = []
      self.stopSignal = stopSignal
    }
  }

  func next(for request: URLRequest) -> (StubHTTPReply, RequestGate?) {
    lock.withLock {
      requests.append(request)
      let reply: StubHTTPReply =
        replies.isEmpty ? .failure(.badServerResponse) : replies.removeFirst()
      return (reply, stopSignal)
    }
  }

  var recordedRequests: [URLRequest] { lock.withLock { requests } }
}

nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  static let state = StubHTTPState()
  private let lock = NSLock()
  private var work: Task<Void, Never>?
  private var isStopped = false
  private var stopSignal: RequestGate?

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let (reply, signal) = Self.state.next(for: request)
    lock.withLock { stopSignal = signal }
    switch reply {
    case .held(let gate):
      waitForRelease(gate, headersSent: false)
    case .streaming(let gate):
      sendHeaders(status: 200, headers: ["Content-Type": "application/json"])
      client?.urlProtocol(self, didLoad: Data([32]))
      waitForRelease(gate, headersSent: true)
    default:
      deliver(reply)
    }
  }

  private func waitForRelease(_ gate: RequestGate, headersSent: Bool) {
    let task = Task {
      await gate.pause()
      guard !Task.isCancelled else { return }
      if headersSent {
        self.client?.urlProtocol(self, didLoad: StubHTTPReply.body)
        self.client?.urlProtocolDidFinishLoading(self)
      } else {
        self.deliver(.ok)
      }
    }
    lock.withLock {
      work = task
      if isStopped { task.cancel() }
    }
  }

  private func sendHeaders(status: Int, headers: [String: String]) {
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
      )
    else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
  }

  private func deliver(_ reply: StubHTTPReply) {
    switch reply {
    case .response(let status, let headers, let chunks):
      sendHeaders(status: status, headers: headers)
      for chunk in chunks {
        guard !lock.withLock({ isStopped }) else { return }
        client?.urlProtocol(self, didLoad: chunk)
      }
      client?.urlProtocolDidFinishLoading(self)
    case .failure(let code):
      client?.urlProtocol(self, didFailWithError: URLError(code))
    case .held, .streaming:
      break
    case .redirect(let url):
      guard let originalURL = request.url,
        let response = HTTPURLResponse(
          url: originalURL, statusCode: 302, httpVersion: "HTTP/1.1",
          headerFields: ["Location": url.absoluteString]
        )
      else { return }
      client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: url), redirectResponse: response)
    }
  }

  override func stopLoading() {
    let signal = lock.withLock {
      isStopped = true
      work?.cancel()
      work = nil
      return stopSignal
    }
    if let signal { Task { await signal.signal() } }
  }
}

// Время повторов движется только по команде теста; общий watchdog использует отдельное ожидание.
nonisolated final class TestNetworkTime: @unchecked Sendable {
  private let lock = NSLock()
  private var elapsed: TimeInterval = 0
  private var waits: [TimeInterval] = []
  let base = Date(timeIntervalSince1970: 1_700_000_000)

  var now: Date { lock.withLock { base.addingTimeInterval(elapsed) } }
  var uptime: TimeInterval { lock.withLock { elapsed } }
  var delays: [TimeInterval] { lock.withLock { waits } }

  func advance(_ seconds: TimeInterval) {
    lock.withLock { elapsed += seconds }
  }

  func timing() -> QuoteNetworkTiming {
    QuoteNetworkTiming(
      now: { self.now },
      uptime: { self.uptime },
      sleep: { seconds in
        try Task.checkCancellation()
        self.lock.withLock {
          self.elapsed += seconds
          self.waits.append(seconds)
        }
      },
      jitter: { $0 }
    )
  }
}
