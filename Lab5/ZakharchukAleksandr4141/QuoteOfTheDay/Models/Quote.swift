import Foundation

nonisolated struct Quote: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let text: String
    let author: String

    init(id: UUID = UUID(), text: String, author: String) {
        self.id = id
        self.text = text
        self.author = author
    }
}
