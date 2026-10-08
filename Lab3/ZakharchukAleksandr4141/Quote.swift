import Foundation

struct Quote: Identifiable, Equatable {
    let id: UUID
    let text: String
    let author: String

    init(id: UUID = UUID(), text: String, author: String) {
        self.id = id
        self.text = text
        self.author = author
    }
}
