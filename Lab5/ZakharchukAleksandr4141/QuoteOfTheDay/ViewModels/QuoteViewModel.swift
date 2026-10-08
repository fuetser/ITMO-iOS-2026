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
    private var hasLoadedInitially = false
    private var favoriteStatusRevision = 0

    init(
        repository: any QuoteRepositoryProtocol = QuoteRepository(),
        storage: any QuoteOfTheDayStorageProtocol = QuoteOfTheDayStorage(),
        favoritesService: any FavoritesServiceProtocol
    ) {
        self.repository = repository
        self.storage = storage
        self.favoritesService = favoritesService
    }

    func loadInitialQuote() async {
        guard !isLoading else { return }
        if hasLoadedInitially {
            await refreshFavoriteStatus()
            return
        }
        if let saved = storage.load(), storage.isToday(saved.date) {
            currentQuote = saved.quote
            hasLoadedInitially = true
            await refreshFavoriteStatus()
        } else {
            await fetchNewQuote()
        }
    }

    func fetchNewQuote() async {
        guard !isLoading, !isSavingFavorite else { return }
        favoriteStatusRevision += 1
        isLoading = true
        loadFailureMessage = nil
        errorMessage = nil
        defer { isLoading = false }

        do {
            let quote = try await repository.randomQuote(excluding: currentQuote)
            try Task.checkCancellation()
            currentQuote = quote
            isFavorite = false
            hasLoadedInitially = true
            do {
                try storage.save(quote: quote, date: .now)
            } catch {
                errorMessage = "Цитата загружена, но не удалось сохранить её для работы без сети."
            }
        } catch {
            if Self.isCancellation(error) { return }
            hasLoadedInitially = true
            if let saved = storage.load() {
                currentQuote = saved.quote
                isFavorite = false
                errorMessage = "Не удалось загрузить цитаты. Показана сохранённая цитата."
            } else {
                currentQuote = nil
                isFavorite = false
                loadFailureMessage = "Не удалось загрузить цитату. Сохранённой цитаты нет."
            }
        }
        await refreshFavoriteStatus()
    }

    func toggleFavorite() async {
        guard !isLoading, !isSavingFavorite, let quote = currentQuote else { return }
        favoriteStatusRevision += 1
        isSavingFavorite = true
        defer { isSavingFavorite = false }
        do {
            // Recheck the database, since the favorites sheet may have changed it.
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
        favoriteStatusRevision += 1
        let revision = favoriteStatusRevision
        do {
            let status = try await favoritesService.isFavorite(quoteId: quote.id)
            // An earlier lookup must not update a newer quote.
            if currentQuote?.id == quote.id, revision == favoriteStatusRevision {
                isFavorite = status
            }
        } catch {
            if !Self.isCancellation(error), errorMessage == nil,
               currentQuote?.id == quote.id, revision == favoriteStatusRevision {
                errorMessage = "Не удалось проверить избранное: \(error.localizedDescription)"
            }
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled
    }
}
