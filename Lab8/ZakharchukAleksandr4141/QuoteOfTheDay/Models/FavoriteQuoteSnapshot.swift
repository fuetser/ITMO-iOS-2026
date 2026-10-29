import Foundation

// Неизменяемая копия записи для интерфейса: сама модель SwiftData остаётся внутри actor.
nonisolated struct FavoriteQuoteSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let text: String
  let author: String
  let addedAt: Date
  let note: String
}
