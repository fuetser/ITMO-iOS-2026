import SwiftData
import SwiftUI

struct ContentView: View {
  let services: AppServices

  @State private var viewModel: QuoteViewModel?
  @State private var favoritesService: (any FavoritesServiceProtocol)?

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        if let viewModel, let favoritesService {
          QuoteScreen(viewModel: viewModel, favoritesService: favoritesService)
        } else {
          ProgressView()
            .tint(.white)
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                  Image(systemName: "heart.text.square")
                    .foregroundStyle(.white)
                }
                .disabled(true)
              }
            }
        }
      }
      .navigationTitle("Цитата дня")
      .navigationBarTitleDisplayMode(.inline)
    }
    .task { await prepareScreen() }
  }

  private func prepareScreen() async {
    guard viewModel == nil else { return }
    do {
      let service = try await services.favorites()
      try Task.checkCancellation()
      favoritesService = service
      viewModel = QuoteViewModel(repository: services.quoteRepository, favoritesService: service)
    } catch {
      // Фабрика бросает только ошибку отмены. При новом появлении экрана повторим подготовку.
      return
    }
  }
}

// Готовый экран получает зависимости напрямую и больше не проверяет их на nil.
private struct QuoteScreen: View {
  @Bindable var viewModel: QuoteViewModel
  let favoritesService: any FavoritesServiceProtocol

  @State private var showFavorites = false
  @State private var actionTask: Task<Void, Never>?

  var body: some View {
    // Постоянная оболочка сохраняет жизнь задачи при смене загрузки, ошибки и цитаты.
    ZStack {
      content
    }
    .toolbar { favoritesToolbar }
    .sheet(
      isPresented: $showFavorites,
      onDismiss: {
        startAction { await viewModel.refreshFavoriteStatus() }
      }
    ) {
      FavoritesView(service: favoritesService)
    }
    .alert("Уведомление", isPresented: isErrorPresented) {
      Button("OK") { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
    .task { await viewModel.loadInitialQuote() }
    .onDisappear { actionTask?.cancel() }
  }

  @ToolbarContentBuilder
  private var favoritesToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        showFavorites = true
      } label: {
        Image(systemName: "heart.text.square")
          .foregroundStyle(.white)
      }
      .disabled(isOpeningFavoritesDisabled)
    }
  }

  private var areQuoteActionsDisabled: Bool {
    actionTask != nil || viewModel.isLoading || viewModel.isSavingFavorite
  }

  private var isOpeningFavoritesDisabled: Bool {
    // Сервис здесь уже готов; остались только проверки текущих операций.
    areQuoteActionsDisabled
  }

  private var isErrorPresented: Binding<Bool> {
    Binding(
      get: { viewModel.errorMessage != nil },
      set: { isPresented in
        if !isPresented { viewModel.errorMessage = nil }
      }
    )
  }

  private func startAction(_ operation: @escaping @MainActor () async -> Void) {
    guard actionTask == nil else { return }
    actionTask = Task {
      await operation()
      actionTask = nil
    }
  }

  @ViewBuilder
  private var content: some View {
    if let quote = viewModel.currentQuote {
      VStack(spacing: 24) {
        Spacer()
        quoteCard(quote)
        if viewModel.isLoading { ProgressView("Загрузка цитаты…").tint(.white) }
        Spacer()
        actionButtons.padding(.bottom, 24)
      }
      .padding(.horizontal, 24)
    } else if viewModel.isLoading {
      ProgressView("Загрузка цитаты…").tint(.white)
    } else {
      VStack(spacing: 20) {
        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
        Text(viewModel.loadFailureMessage ?? "Цитата пока не загружена.")
          .multilineTextAlignment(.center)
        Button("Повторить") {
          startAction { await viewModel.fetchNewQuote() }
        }
        .buttonStyle(.borderedProminent)
      }
      .foregroundStyle(.white)
      .padding(32)
    }
  }

  private func quoteCard(_ quote: Quote) -> some View {
    VStack(spacing: 16) {
      Text("«\(quote.text)»")
        .font(.title2)
        .fontWeight(.medium)
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .animation(.easeInOut, value: quote)
      Text("— \(quote.author)")
        .font(.subheadline)
        .italic()
        .foregroundStyle(.white.opacity(0.8))

    }
    .padding(28)
    .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
    .padding(.horizontal, 8)
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        startAction { await viewModel.fetchNewQuote() }
      } label: {
        Label("Другая цитата", systemImage: "arrow.triangle.2.circlepath")
          .font(.headline)
          .padding(.vertical, 14)
          .frame(maxWidth: .infinity)
          .background(.white)
          .foregroundStyle(.indigo)
          .clipShape(Capsule())
      }
      Button {
        startAction { await viewModel.toggleFavorite() }
      } label: {
        HStack {
          if viewModel.isSavingFavorite { ProgressView().tint(.white) }
          Label(
            viewModel.isFavorite ? "Убрать из избранного" : "В избранное",
            systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
          )
        }
        .font(.headline)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.2))
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
      }
    }
    .buttonStyle(.plain)
    .disabled(areQuoteActionsDisabled)
  }
}

#Preview {
  // Ошибка создания базы в памяти должна остановить Preview и показать причину.
  ContentView(
    services: AppServices(
      container: try! ModelContainer(
        for: FavoriteQuote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
    )
  )
}
