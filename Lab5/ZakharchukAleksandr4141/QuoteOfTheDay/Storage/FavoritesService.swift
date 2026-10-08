import Foundation
import SwiftData

nonisolated protocol FavoritesServiceProtocol: Sendable {
    func add(_ quote: Quote) async throws
    func fetchAll() async throws -> [FavoriteQuoteSnapshot]
    func isFavorite(quoteId: UUID) async throws -> Bool
    func update(quoteId: UUID, note: String) async throws
    func delete(quoteId: UUID) async throws
    func deleteAll() async throws
}

nonisolated enum FavoritesServiceError: LocalizedError {
    case notFound

    var errorDescription: String? { "Цитата больше не находится в избранном." }
}

@ModelActor
actor FavoritesService: FavoritesServiceProtocol {
    func add(_ quote: Quote) async throws {
        try Task.checkCancellation()
        try transaction {
            guard try find(quoteId: quote.id) == nil else { return }
            modelContext.insert(FavoriteQuote(from: quote))
        }
    }

    func fetchAll() async throws -> [FavoriteQuoteSnapshot] {
        try Task.checkCancellation()
        let descriptor = FetchDescriptor<FavoriteQuote>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map {
            FavoriteQuoteSnapshot(
                id: $0.quoteId, text: $0.text, author: $0.author,
                addedAt: $0.addedAt, note: $0.note
            )
        }
    }

    func isFavorite(quoteId: UUID) async throws -> Bool {
        try Task.checkCancellation()
        return try find(quoteId: quoteId) != nil
    }

    func update(quoteId: UUID, note: String) async throws {
        try Task.checkCancellation()
        try transaction {
            guard let favorite = try find(quoteId: quoteId) else {
                throw FavoritesServiceError.notFound
            }
            favorite.note = note
        }
    }

    func delete(quoteId: UUID) async throws {
        try Task.checkCancellation()
        try transaction {
            if let favorite = try find(quoteId: quoteId) {
                modelContext.delete(favorite)
            }
        }
    }

    func deleteAll() async throws {
        try Task.checkCancellation()
        try transaction {
            let all = try modelContext.fetch(FetchDescriptor<FavoriteQuote>())
            for favorite in all {
                modelContext.delete(favorite)
            }
        }
    }

    private func find(quoteId: UUID) throws -> FavoriteQuote? {
        var descriptor = FetchDescriptor<FavoriteQuote>(
            predicate: #Predicate { $0.quoteId == quoteId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // There is no suspension between changing models and committing the transaction.
    private func transaction(_ changes: () throws -> Void) throws {
        do {
            try changes()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

nonisolated enum FavoritesServiceFactory {
    // ModelActor creates its context on the executor where it is initialized.
    // @concurrent keeps that initialization off MainActor, even with
    // SWIFT_APPROACHABLE_CONCURRENCY enabled.
    @concurrent
    static func make(container: ModelContainer) async throws -> FavoritesService {
        try Task.checkCancellation()
        let service = FavoritesService(modelContainer: container)
        return service
    }
}
