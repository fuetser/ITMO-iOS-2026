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
protocol UserDefaultsProtocol {
  func set(_ value: Any?, forKey defaultName: String)
  func data(forKey defaultName: String) -> Data?
  func removeObject(forKey defaultName: String)
}

extension UserDefaults: UserDefaultsProtocol {}

@MainActor
final class QuoteOfTheDayStorage: QuoteOfTheDayStorageProtocol {
  private enum Keys {
    static let snapshot = "quoteOfTheDay.snapshot"
  }

  private let defaults: any UserDefaultsProtocol
  private let calendar: Calendar

  init(defaults: any UserDefaultsProtocol = UserDefaults.standard, calendar: Calendar = .current) {
    self.defaults = defaults
    self.calendar = calendar
  }

  func save(quote: Quote, date: Date) throws {
    let data = try JSONEncoder().encode(SavedQuote(quote: quote, date: date))
    defaults.set(data, forKey: Keys.snapshot)
  }

  func load() -> SavedQuote? {
    guard let data = defaults.data(forKey: Keys.snapshot) else { return nil }
    // Отсутствующая или повреждённая запись означает, что сохранённой цитаты нет.
    guard let saved = try? JSONDecoder().decode(SavedQuote.self, from: data) else { return nil }
    guard !saved.quote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !saved.quote.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }
    return saved
  }

  func clear() {
    defaults.removeObject(forKey: Keys.snapshot)
  }

  func isToday(_ date: Date) -> Bool {
    calendar.isDateInToday(date)
  }
}
