//
//  FavoritesView.swift
//  QuoteOfTheDay
//
//  Created by a.zakharchuk on 01.10.2026.
//


import SwiftUI
import SwiftData

struct FavoritesView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FavoritesViewModel()

    // автоматически обновляется при изменениях в БД
    @Query(sort: \FavoriteQuote.addedAt, order: .reverse)
    private var favorites: [FavoriteQuote]

    @State private var editingFavorite: FavoriteQuote?
    @State private var showDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    emptyState
                } else {
                    favoritesList
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !favorites.isEmpty {
                        Button(role: .destructive) {
                            showDeleteAllAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .sheet(item: $editingFavorite) { favorite in
                EditFavoriteView(favorite: favorite)
            }
            .alert("Удалить всё избранное?", isPresented: $showDeleteAllAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    viewModel.deleteAll(context: context)
                }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Пока пусто")
                .font(.headline)
            Text("Добавляй цитаты в избранное с главного экрана.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(favorites) { favorite in
                Button {
                    editingFavorite = favorite
                } label: {
                    row(favorite)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
    }

    private func row(_ favorite: FavoriteQuote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("«\(favorite.text)»")
                .font(.body)
                .foregroundStyle(.primary)

            Text("— \(favorite.author)")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)

            if !favorite.note.isEmpty {
                Text("📝 \(favorite.note)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let favorite = favorites[index]
            viewModel.delete(favorite, context: context)
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: FavoriteQuote.self, inMemory: true)
}
