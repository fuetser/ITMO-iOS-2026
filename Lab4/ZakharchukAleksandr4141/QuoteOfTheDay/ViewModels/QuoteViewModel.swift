//
//  QuoteViewModel.swift
//  QuoteOfTheDay
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class QuoteViewModel {

    private(set) var currentQuote: Quote
    private(set) var isFavorite: Bool = false
    var errorMessage: String?

    private let repository: QuoteRepositoryProtocol
    private let storage: QuoteOfTheDayStorageProtocol
    private let favoritesService: FavoritesServiceProtocol
    private let context: ModelContext

    init(
        repository: QuoteRepositoryProtocol = QuoteRepository(),
        storage: QuoteOfTheDayStorageProtocol = QuoteOfTheDayStorage(),
        favoritesService: FavoritesServiceProtocol = FavoritesService(),
        context: ModelContext
    ) {
        self.repository = repository
        self.storage = storage
        self.favoritesService = favoritesService
        self.context = context

        if let saved = storage.load(),
           storage.isToday(saved.date),
           let quote = repository.quote(withId: saved.quoteId) {
            self.currentQuote = quote
        } else {
            let quote = repository.randomQuote(excluding: nil)
            self.currentQuote = quote
            storage.save(quoteId: quote.id, date: .now)
        }

        refreshFavoriteStatus()
    }

    func fetchNewQuote() {
        let quote = repository.randomQuote(excluding: currentQuote)
        currentQuote = quote
        storage.save(quoteId: quote.id, date: .now)
        refreshFavoriteStatus()
    }

    func toggleFavorite() {
        do {
            if isFavorite {
                let favorites = try favoritesService.fetchAll(context: context)
                if let existing = favorites.first(where: { $0.quoteId == currentQuote.id }) {
                    try favoritesService.delete(existing, context: context)
                }
            } else {
                try favoritesService.add(currentQuote, context: context)
            }
            refreshFavoriteStatus()
        } catch {
            errorMessage = "Не удалось изменить избранное: \(error.localizedDescription)"
        }
    }

    private func refreshFavoriteStatus() {
        do {
            isFavorite = try favoritesService.isFavorite(
                quoteId: currentQuote.id,
                context: context
            )
        } catch {
            isFavorite = false
        }
    }
}
