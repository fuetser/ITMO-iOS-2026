//
//  Quote.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 24.09.2026.
//


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
