import Observation

@MainActor
@Observable
final class QuoteViewModel {
    private(set) var currentQuote: Quote

    private let repository: QuoteRepositoryProtocol

    init(repository: QuoteRepositoryProtocol = QuoteRepository()) {
        self.repository = repository
        self.currentQuote = repository.randomQuote(excluding: nil)
            ?? Quote(text: "Сегодня хорошее время начать.", author: "")
    }

    func fetchNewQuote() {
        guard let quote = repository.randomQuote(excluding: currentQuote) else { return }
        currentQuote = quote
    }
}
