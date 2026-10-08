//
//  QuoteOfTheDayStorage.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//


import Foundation

protocol QuoteOfTheDayStorageProtocol {
    func save(quoteId: UUID, date: Date)
    func load() -> (quoteId: UUID, date: Date)?
    func clear()
    func isToday(_ date: Date) -> Bool
}

final class QuoteOfTheDayStorage: QuoteOfTheDayStorageProtocol {
    private enum Keys {
        static let quoteId = "quoteOfTheDay.id"
        static let date = "quoteOfTheDay.date"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func save(quoteId: UUID, date: Date) {
        defaults.set(quoteId.uuidString, forKey: Keys.quoteId)
        defaults.set(date, forKey: Keys.date)
    }

    func load() -> (quoteId: UUID, date: Date)? {
        guard
            let idString = defaults.string(forKey: Keys.quoteId),
            let quoteId = UUID(uuidString: idString),
            let date = defaults.object(forKey: Keys.date) as? Date
        else {
            return nil
        }
        return (quoteId, date)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.quoteId)
        defaults.removeObject(forKey: Keys.date)
    }
    
    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}
