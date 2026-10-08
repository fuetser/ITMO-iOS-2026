//
//  FavoritesService.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//


import Foundation
import SwiftData

protocol FavoritesServiceProtocol {
    func add(_ quote: Quote, context: ModelContext) throws
    func fetchAll(context: ModelContext) throws -> [FavoriteQuote]
    func isFavorite(quoteId: UUID, context: ModelContext) throws -> Bool
    func update(_ favorite: FavoriteQuote, note: String, context: ModelContext) throws
    func delete(_ favorite: FavoriteQuote, context: ModelContext) throws
    func deleteAll(context: ModelContext) throws
}

final class FavoritesService: FavoritesServiceProtocol {
    func add(_ quote: Quote, context: ModelContext) throws {
        // если уже в избранном — ничего не делаем
        if try isFavorite(quoteId: quote.id, context: context) {
            return
        }
        let favorite = FavoriteQuote(from: quote)
        context.insert(favorite)
        try context.save()
    }

    func fetchAll(context: ModelContext) throws -> [FavoriteQuote] {
        let descriptor = FetchDescriptor<FavoriteQuote>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func isFavorite(quoteId: UUID, context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<FavoriteQuote>(
            predicate: #Predicate { $0.quoteId == quoteId }
        )
        descriptor.fetchLimit = 1
        let result = try context.fetch(descriptor)
        return !result.isEmpty
    }

    func update(_ favorite: FavoriteQuote, note: String, context: ModelContext) throws {
        favorite.note = note
        try context.save()
    }

    func delete(_ favorite: FavoriteQuote, context: ModelContext) throws {
        context.delete(favorite)
        try context.save()
    }

    func deleteAll(context: ModelContext) throws {
        let all = try fetchAll(context: context)
        for item in all {
            context.delete(item)
        }
        try context.save()
    }
}
