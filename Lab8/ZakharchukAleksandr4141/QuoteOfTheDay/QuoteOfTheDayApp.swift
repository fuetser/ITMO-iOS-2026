import Foundation
import SwiftData
import SwiftUI

@main
struct QuoteOfTheDayApp: App {
  @State private var services: AppServices?
  private let initializationError: String?

  init() {
    do {
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
          let container = try ModelContainer(
            for: FavoriteQuote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
          )
          let suiteName = "com.fuetser.QuoteOfTheDay.UITests"
          guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CocoaError(.fileReadUnknown)
          }
          defaults.removePersistentDomain(forName: suiteName)
          _services = State(initialValue: AppServices(
            container: container,
            quoteRepository: UITestQuoteRepository(),
            quoteStorage: QuoteOfTheDayStorage(defaults: defaults)
          ))
          initializationError = nil
          return
        }
      #endif
      let container = try ModelContainer(for: FavoriteQuote.self)
      _services = State(initialValue: AppServices(container: container))
      initializationError = nil
    } catch {
      _services = State(initialValue: nil)
      initializationError = error.localizedDescription
    }
  }

  var body: some Scene {
    WindowGroup {
      if let services {
        ContentView(services: services)
      } else {
        ContentUnavailableView(
          "Не удалось открыть базу данных",
          systemImage: "externaldrive.badge.exclamationmark",
          description: Text(initializationError ?? "Попробуйте перезапустить приложение.")
        )
      }
    }
  }
}

#if DEBUG
  // UI-тесты проходят через обычный интерфейс, но не зависят от внешнего API.
  private actor UITestQuoteRepository: QuoteRepositoryProtocol {
    private var requestCount = 0

    func randomQuote() async throws -> Quote {
      requestCount += 1
      if requestCount == 1 {
        return Quote(
          id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
          text: "First test quote.", author: "First Author"
        )
      }
      return Quote(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
        text: "Second test quote.", author: "Second Author"
      )
    }
  }
#endif
