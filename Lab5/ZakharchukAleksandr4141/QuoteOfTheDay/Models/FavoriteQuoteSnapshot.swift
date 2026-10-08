import Foundation

nonisolated struct FavoriteQuoteSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let author: String
    let addedAt: Date
    let note: String
}
