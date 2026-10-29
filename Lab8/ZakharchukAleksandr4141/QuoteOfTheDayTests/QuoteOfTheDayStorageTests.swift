import Foundation
import XCTest

@testable import QuoteOfTheDay

@MainActor
final class QuoteOfTheDayStorageTests: XCTestCase {
  private var defaults: UserDefaultsMock!
  private var storage: QuoteOfTheDayStorage!

  private let quote = Quote(text: "Stay curious.", author: "Test Author")
  private let date = Date(timeIntervalSince1970: 1_700_000_000)

  override func setUp() async throws {
    try await super.setUp()

    defaults = UserDefaultsMock()
    storage = QuoteOfTheDayStorage(defaults: defaults)
  }

  override func tearDown() async throws {
    storage = nil
    defaults = nil

    try await super.tearDown()
  }

  func testSaveRestoresQuoteAndDateInNewStorageInstance() throws {
    try storage.save(quote: quote, date: date)

    let restoredStorage = QuoteOfTheDayStorage(defaults: defaults)
    let restoredQuote = restoredStorage.load()

    XCTAssertEqual(restoredQuote, SavedQuote(quote: quote, date: date))
  }

  func testClearRemovesSavedQuoteAndPreservesOtherSettings() throws {
    defaults.set("dark", forKey: "theme")
    try storage.save(quote: quote, date: date)

    XCTAssertNotNil(storage.load())

    storage.clear()

    let restoredStorage = QuoteOfTheDayStorage(defaults: defaults)

    XCTAssertNil(restoredStorage.load())
    XCTAssertEqual(defaults.values["theme"] as? String, "dark")
    XCTAssertEqual(defaults.removedKeys, ["quoteOfTheDay.snapshot"])
  }
}

@MainActor
private final class UserDefaultsMock: UserDefaultsProtocol {
  private(set) var values: [String: Any] = [:]
  private(set) var removedKeys: [String] = []

  func set(_ value: Any?, forKey defaultName: String) {
    values[defaultName] = value
  }

  func data(forKey defaultName: String) -> Data? {
    values[defaultName] as? Data
  }

  func removeObject(forKey defaultName: String) {
    removedKeys.append(defaultName)
    values.removeValue(forKey: defaultName)
  }
}
