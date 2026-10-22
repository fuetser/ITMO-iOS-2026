import Foundation
import XCTest

@testable import QuoteOfTheDay

final class QuoteOfTheDayStorageTests: XCTestCase {
  @MainActor
  func testSaveRestoresQuoteAndDateInNewStorageInstance() throws {
    let suiteName = "QuoteOfTheDayStorageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let storage = QuoteOfTheDayStorage(defaults: defaults)
    let quote = Quote(text: "Stay curious.", author: "Test Author")
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    try storage.save(quote: quote, date: date)

    let restoredStorage = QuoteOfTheDayStorage(defaults: defaults)
    XCTAssertEqual(restoredStorage.load(), SavedQuote(quote: quote, date: date))
  }

  @MainActor
  func testClearRemovesSavedQuoteAndPreservesOtherSettings() throws {
    let suiteName = "QuoteOfTheDayStorageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let storage = QuoteOfTheDayStorage(defaults: defaults)
    defaults.set("dark", forKey: "theme")
    try storage.save(quote: Quote(text: "Stay curious.", author: "Test Author"), date: .now)
    XCTAssertNotNil(storage.load())

    storage.clear()

    XCTAssertNil(QuoteOfTheDayStorage(defaults: defaults).load())
    XCTAssertEqual(defaults.string(forKey: "theme"), "dark")
  }
}
