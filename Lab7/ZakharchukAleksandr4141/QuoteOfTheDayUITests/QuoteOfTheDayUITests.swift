import XCTest

final class QuoteOfTheDayUITests: XCTestCase {
  @MainActor
  private func launchApp() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    XCTAssertTrue(app.staticTexts["quoteText"].waitForExistence(timeout: 10))
    return app
  }

  @MainActor
  func testAnotherQuoteChangesTextAndAuthor() {
    let app = launchApp()
    XCTAssertEqual(app.staticTexts["quoteText"].label, "«First test quote.»")
    XCTAssertEqual(app.staticTexts["quoteAuthor"].label, "— First Author")

    app.buttons["newQuoteButton"].tap()

    let updatedQuote = NSPredicate(format: "label == %@", "«Second test quote.»")
    expectation(for: updatedQuote, evaluatedWith: app.staticTexts["quoteText"])
    waitForExpectations(timeout: 5)
    XCTAssertEqual(app.staticTexts["quoteAuthor"].label, "— Second Author")
  }

  @MainActor
  func testFavoriteCanBeAddedAndRemoved() {
    let app = launchApp()
    let favoriteButton = app.buttons["toggleFavoriteButton"]
    XCTAssertEqual(favoriteButton.label, "В избранное")
    favoriteButton.tap()
    let added = NSPredicate(format: "label == %@ AND enabled == true", "Убрать из избранного")
    expectation(for: added, evaluatedWith: favoriteButton)
    waitForExpectations(timeout: 5)
    app.buttons["openFavoritesButton"].tap()
    XCTAssertTrue(app.staticTexts["«First test quote.»"].waitForExistence(timeout: 5))
    app.buttons["closeFavoritesButton"].tap()
    XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
    favoriteButton.tap()

    let removed = NSPredicate(format: "label == %@ AND enabled == true", "В избранное")
    expectation(for: removed, evaluatedWith: favoriteButton)
    waitForExpectations(timeout: 5)
    app.buttons["openFavoritesButton"].tap()
    XCTAssertTrue(app.staticTexts["Пока пусто"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["«First test quote.»"].exists)
  }
}
