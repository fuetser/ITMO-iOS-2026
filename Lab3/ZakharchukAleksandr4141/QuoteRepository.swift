import Foundation

protocol QuoteRepositoryProtocol {
    var allQuotes: [Quote] { get }
    func randomQuote(excluding current: Quote?) -> Quote?
}

struct QuoteRepository: QuoteRepositoryProtocol {
    let allQuotes: [Quote] = [
        Quote(text: "Жизнь — это то, что происходит, пока ты строишь планы.", author: "Джон Леннон"),
        Quote(text: "Единственный способ делать великие дела — любить то, что ты делаешь.", author: "Стив Джобс"),
        Quote(text: "Успех — это способность идти от неудачи к неудаче, не теряя энтузиазма.", author: "Уинстон Черчилль"),
        Quote(text: "Будь тем изменением, которое хочешь видеть в мире.", author: "Махатма Ганди"),
        Quote(text: "Сложнее всего начать действовать, всё остальное зависит только от упорства.", author: "Амелия Эрхарт"),
        Quote(text: "Не бойся медленно идти, бойся стоять на месте.", author: "Китайская пословица"),
        Quote(text: "Счастье — это не что-то готовое. Оно происходит из твоих собственных действий.", author: "Далай-лама"),
        Quote(text: "Знание — сила.", author: "Фрэнсис Бэкон"),
        Quote(text: "Мы — то, что мы делаем постоянно. Совершенство — не действие, а привычка.", author: "Аристотель"),
        Quote(text: "Стремись не к успеху, а к тому, чтобы твоя жизнь имела смысл.", author: "Альберт Эйнштейн")
    ]

    func randomQuote(excluding current: Quote?) -> Quote? {
        let candidates = allQuotes.filter { $0.id != current?.id }
        return (candidates.isEmpty ? allQuotes : candidates).randomElement()
    }
}
