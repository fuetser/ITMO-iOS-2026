//
//  QuoteRepository.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//

import Foundation

protocol QuoteRepositoryProtocol {
    var allQuotes: [Quote] { get }
    func randomQuote(excluding current: Quote?) -> Quote
    func quote(withId id: UUID) -> Quote?
}

final class QuoteRepository: QuoteRepositoryProtocol {
    let allQuotes: [Quote] = [
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            text: "Жизнь — это то, что происходит, пока ты строишь планы.",
            author: "Джон Леннон"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            text: "Единственный способ делать великую работу — любить то, что ты делаешь.",
            author: "Стив Джобс"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            text: "Успех — это способность идти от неудачи к неудаче, не теряя энтузиазма.",
            author: "Уинстон Черчилль"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            text: "Будь тем изменением, которое ты хочешь видеть в мире.",
            author: "Махатма Ганди"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            text: "Сложнее всего начать действовать, всё остальное зависит только от упорства.",
            author: "Амелия Эрхарт"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            text: "Не бойся медленно идти, бойся стоять на месте.",
            author: "Китайская пословица"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            text: "Счастье — это не что-то готовое. Оно происходит из твоих собственных действий.",
            author: "Далай-лама"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            text: "Знание — сила.",
            author: "Фрэнсис Бэкон"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            text: "Мы то, что мы делаем постоянно. Совершенство — не действие, а привычка.",
            author: "Аристотель"
        ),
        Quote(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            text: "Стремись не к успеху, а к тому, чтобы твоя жизнь имела смысл.",
            author: "Альберт Эйнштейн"
        )
    ]


    func randomQuote(excluding current: Quote?) -> Quote {
        guard let candidate = allQuotes.randomElement() else {
            fatalError("Список цитат пуст")
        }
        guard allQuotes.count > 1, let current, candidate.id == current.id else {
            return candidate
        }

        let otherQuotes = allQuotes.filter { $0.id != current.id }
        return otherQuotes.randomElement() ?? candidate
    }

    func quote(withId id: UUID) -> Quote? {
        allQuotes.first { $0.id == id }
    }
}
