import Foundation

nonisolated protocol QuoteRepositoryProtocol: Sendable {
    func randomQuote(excluding current: Quote?) async throws -> Quote
}

nonisolated enum QuoteRepositoryError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case emptyCatalog
    case invalidQuote

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Сервер вернул некорректный ответ."
        case .httpStatus(let status): "Ошибка сервера: HTTP \(status)."
        case .emptyCatalog: "Сервер вернул пустой список цитат."
        case .invalidQuote: "Сервер вернул некорректную цитату."
        }
    }
}

nonisolated final class QuoteRepository: QuoteRepositoryProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // Decoding also runs outside the caller's MainActor with approachable concurrency.
    @concurrent
    func randomQuote(excluding current: Quote?) async throws -> Quote {
        var request = URLRequest(url: URL(string: "https://dummyjson.com/quotes?limit=0")!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw QuoteRepositoryError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QuoteRepositoryError.httpStatus(http.statusCode)
        }
        let payload = try JSONDecoder().decode(QuotesResponse.self, from: data)
        let quotes = try payload.quotes.map { try $0.asQuote() }
        guard !quotes.isEmpty else { throw QuoteRepositoryError.emptyCatalog }
        let alternatives = quotes.filter { $0.id != current?.id }
        try Task.checkCancellation()
        return (alternatives.isEmpty ? quotes : alternatives).randomElement()!
    }
}

nonisolated private struct QuotesResponse: Decodable {
    let quotes: [APIQuote]
}

nonisolated private struct APIQuote: Decodable {
    let id: Int64
    let quote: String
    let author: String

    func asQuote() throws -> Quote {
        guard id > 0, id <= 0xFFFFFFFFFFFF,
              !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw QuoteRepositoryError.invalidQuote
        }
        let suffix = String(format: "%012llX", id)
        guard let uuid = UUID(uuidString: "D00D0000-0000-4000-8000-\(suffix)") else {
            throw QuoteRepositoryError.invalidQuote
        }
        return Quote(id: uuid, text: quote, author: author)
    }
}
