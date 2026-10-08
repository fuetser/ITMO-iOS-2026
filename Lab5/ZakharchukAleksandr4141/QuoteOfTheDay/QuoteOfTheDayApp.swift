import SwiftUI
import SwiftData

@main
struct QuoteOfTheDayApp: App {
    @State private var services: AppServices?
    private let initializationError: String?

    init() {
        do {
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
