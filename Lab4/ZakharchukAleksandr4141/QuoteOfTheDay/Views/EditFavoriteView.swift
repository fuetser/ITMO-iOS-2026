//
//  EditFavoriteView.swift
//  QuoteOfTheDay
//

import SwiftUI
import SwiftData

struct EditFavoriteView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var favorite: FavoriteQuote
    @StateObject private var viewModel = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Цитата") {
                    Text("«\(favorite.text)»")
                        .font(.body)
                    Text("— \(favorite.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Заметка") {
                    TextField(
                        "Твоя заметка к цитате...",
                        text: $favorite.note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section {
                    Text("Добавлено: \(favorite.addedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        viewModel.update(favorite, note: favorite.note, context: context)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FavoriteQuote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let sample = FavoriteQuote(
        quoteId: UUID(),
        text: "Мы то, что мы делаем постоянно.",
        author: "Аристотель",
        note: "Тестовая заметка"
    )
    container.mainContext.insert(sample)
    return EditFavoriteView(favorite: sample)
        .modelContainer(container)
}
