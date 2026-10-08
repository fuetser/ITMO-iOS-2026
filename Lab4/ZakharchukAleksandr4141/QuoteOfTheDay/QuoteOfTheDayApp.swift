//
//  QuoteOfTheDayApp.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 24.09.2026.
//

import SwiftUI
import SwiftData

@main
struct QuoteOfTheDayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FavoriteQuote.self)
    }
}
