import SwiftUI

struct FavoritesView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel: FavoritesViewModel
  @State private var editingFavorite: FavoriteQuoteSnapshot?
  @State private var showDeleteAllAlert = false
  @State private var actionTask: Task<Void, Never>?

  init(service: any FavoritesServiceProtocol) {
    _viewModel = State(initialValue: FavoritesViewModel(service: service))
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Избранное")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { favoritesToolbar }
        .sheet(item: $editingFavorite) { favorite in
          EditFavoriteView(favorite: favorite, viewModel: viewModel)
        }
        .alert("Удалить всё избранное?", isPresented: $showDeleteAllAlert) {
          Button("Отмена", role: .cancel) {}
          Button("Удалить", role: .destructive) {
            startAction { await viewModel.deleteAll() }
          }
        } message: {
          Text("Это действие нельзя отменить.")
        }
        .alert("Ошибка", isPresented: isErrorPresented) {
          Button("OK") { viewModel.errorMessage = nil }
        } message: {
          Text(viewModel.errorMessage ?? "")
        }
    }
    .task { await viewModel.loadFavorites() }
    .interactiveDismissDisabled(isClosingDisabled)
    .onDisappear { actionTask?.cancel() }
  }

  private var isClosingDisabled: Bool {
    viewModel.isSaving || actionTask != nil
  }

  private var isDeleteAllButtonDisabled: Bool {
    viewModel.isLoading || actionTask != nil
  }

  private var areListActionsDisabled: Bool {
    actionTask != nil || viewModel.isLoading || viewModel.isSaving
  }

  private var isErrorPresented: Binding<Bool> {
    Binding(
      // Ошибку сохранения показывает редактор; список не должен открывать второй alert.
      get: { viewModel.errorMessage != nil && editingFavorite == nil },
      set: { isPresented in
        if !isPresented { viewModel.errorMessage = nil }
      }
    )
  }

  private var content: some View {
    Group {
      if viewModel.isLoading && !viewModel.hasLoaded {
        ProgressView("Загрузка избранного…")
      } else if !viewModel.hasLoaded {
        ContentUnavailableView {
          Label("Не удалось загрузить избранное", systemImage: "exclamationmark.triangle")
        } actions: {
          Button("Повторить") {
            startAction { await viewModel.loadFavorites() }
          }
        }
      } else if viewModel.favorites.isEmpty {
        ContentUnavailableView(
          "Пока пусто",
          systemImage: "heart.slash",
          description: Text("Добавляйте цитаты в избранное с главного экрана.")
        )
      } else {
        favoritesList
      }
    }
  }

  @ToolbarContentBuilder
  private var favoritesToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button("Закрыть") { dismiss() }
        .disabled(isClosingDisabled)
        .accessibilityIdentifier("closeFavoritesButton")
    }
    ToolbarItem(placement: .topBarTrailing) {
      if viewModel.isSaving {
        ProgressView()
      } else if !viewModel.favorites.isEmpty {
        Button(role: .destructive) {
          showDeleteAllAlert = true
        } label: {
          Image(systemName: "trash")
        }
        .disabled(isDeleteAllButtonDisabled)
      }
    }
  }

  private func startAction(_ operation: @escaping @MainActor () async -> Void) {
    guard actionTask == nil else { return }
    actionTask = Task {
      await operation()
      actionTask = nil
    }
  }

  private var favoritesList: some View {
    List {
      ForEach(viewModel.favorites) { favorite in
        Button { editingFavorite = favorite } label: {
          VStack(alignment: .leading, spacing: 6) {
            Text("«\(favorite.text)»").font(.body).foregroundStyle(.primary)
            Text("— \(favorite.author)")
              .font(.caption).italic().foregroundStyle(.secondary)
            if !favorite.note.isEmpty {
              Text("📝 \(favorite.note)")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 2)
            }
          }
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
      }
      .onDelete { offsets in
        let ids = offsets.map { offset in viewModel.favorites[offset].id }
        startAction { await viewModel.delete(quoteIds: ids) }
      }
    }
    .listStyle(.plain)
    .disabled(areListActionsDisabled)
  }
}
