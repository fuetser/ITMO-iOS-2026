import Foundation

nonisolated struct SavedQuote: Codable, Equatable, Sendable {
    let quote: Quote
    let date: Date
}

@MainActor
protocol QuoteOfTheDayStorageProtocol {
    func save(quote: Quote, date: Date) throws
    func load() -> SavedQuote?
    func clear()
    func isToday(_ date: Date) -> Bool
}

@MainActor
final class QuoteOfTheDayStorage: QuoteOfTheDayStorageProtocol {
    private enum Keys {
        static let snapshot = "quoteOfTheDay.snapshot"
        static let quoteId = "quoteOfTheDay.id"
        static let date = "quoteOfTheDay.date"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func save(quote: Quote, date: Date) throws {
        let data = try JSONEncoder().encode(SavedQuote(quote: quote, date: date))
        defaults.set(data, forKey: Keys.snapshot)
        clearLegacyKeys()
    }

    func load() -> SavedQuote? {
        if let data = defaults.data(forKey: Keys.snapshot) {
            guard let saved = try? JSONDecoder().decode(SavedQuote.self, from: data),
                  !saved.quote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !saved.quote.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return saved
        }
        // Preserve a previously saved quote and its original date exactly once.
        guard let idString = defaults.string(forKey: Keys.quoteId),
              let id = UUID(uuidString: idString),
              let date = defaults.object(forKey: Keys.date) as? Date,
              let quote = LegacyQuoteCatalog.quotes.first(where: { $0.id == id }) else {
            clearLegacyKeys()
            return nil
        }
        do {
            try save(quote: quote, date: date)
            return SavedQuote(quote: quote, date: date)
        } catch {
            return nil
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.snapshot)
        clearLegacyKeys()
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func clearLegacyKeys() {
        defaults.removeObject(forKey: Keys.quoteId)
        defaults.removeObject(forKey: Keys.date)
    }
}
