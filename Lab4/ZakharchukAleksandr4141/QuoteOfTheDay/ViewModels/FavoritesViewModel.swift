//
//  FavoritesViewModel.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var errorMessage: String?

    private let service: FavoritesServiceProtocol

    init(service: FavoritesServiceProtocol = FavoritesService()) {
        self.service = service
    }

    func delete(_ favorite: FavoriteQuote, context: ModelContext) {
        do {
            try service.delete(favorite, context: context)
        } catch {
            errorMessage = "Не удалось удалить: \(error.localizedDescription)"
        }
    }

    func deleteAll(context: ModelContext) {
        do {
            try service.deleteAll(context: context)
        } catch {
            errorMessage = "Не удалось очистить избранное: \(error.localizedDescription)"
        }
    }

    func update(_ favorite: FavoriteQuote, note: String, context: ModelContext) {
        do {
            try service.update(favorite, note: note, context: context)
        } catch {
            errorMessage = "Не удалось сохранить заметку: \(error.localizedDescription)"
        }
    }
}
