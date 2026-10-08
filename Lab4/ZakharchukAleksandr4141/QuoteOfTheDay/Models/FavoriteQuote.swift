//
//  FavoriteQuote.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//

import Foundation
import SwiftData

@Model
final class FavoriteQuote {
    @Attribute(.unique) var quoteId: UUID
    var text: String
    var author: String
    var addedAt: Date
    var note: String

    init(
        quoteId: UUID,
        text: String,
        author: String,
        addedAt: Date = .now,
        note: String = ""
    ) {
        self.quoteId = quoteId
        self.text = text
        self.author = author
        self.addedAt = addedAt
        self.note = note
    }
}

extension FavoriteQuote {
    convenience init(from quote: Quote) {
        self.init(
            quoteId: quote.id,
            text: quote.text,
            author: quote.author
        )
    }
}
