import SwiftUI
import SwiftData

struct ContentView: View {
    let services: AppServices

    @State private var viewModel: QuoteViewModel?
    @State private var favoritesService: (any FavoritesServiceProtocol)?
    @State private var showFavorites = false
    @State private var actionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle("Цитата дня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFavorites = true
                    } label: {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.white)
                    }
                    .disabled(favoritesService == nil || actionTask != nil || viewModel?.isLoading == true || viewModel?.isSavingFavorite == true)
                }
            }
            .sheet(isPresented: $showFavorites, onDismiss: {
                startAction { await viewModel?.refreshFavoriteStatus() }
            }) {
                if let favoritesService {
                    FavoritesView(service: favoritesService)
                }
            }
            .alert(
                "Уведомление",
                isPresented: Binding(
                    get: { viewModel?.errorMessage != nil },
                    set: { if !$0 { viewModel?.errorMessage = nil } }
                )
            ) {
                Button("OK") { viewModel?.errorMessage = nil }
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
        }
        .task {
            if viewModel == nil {
                do {
                    let service = try await services.favorites()
                    try Task.checkCancellation()
                    favoritesService = service
                    viewModel = QuoteViewModel(favoritesService: service)
                } catch {
                    // Factory only throws on cancellation. A later appearance retries it.
                    return
                }
            }
            await viewModel?.loadInitialQuote()
        }
        .onDisappear { actionTask?.cancel() }
    }

    private func startAction(_ operation: @escaping @MainActor () async -> Void) {
        guard actionTask == nil else { return }
        actionTask = Task {
            await operation()
            actionTask = nil
        }
    }

    @ViewBuilder
    private func content(vm: QuoteViewModel) -> some View {
        if let quote = vm.currentQuote {
            VStack(spacing: 24) {
                Spacer()
                quoteCard(quote)
                if vm.isLoading { ProgressView("Загрузка цитаты…").tint(.white) }
                Spacer()
                actionButtons(vm: vm).padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        } else if vm.isLoading {
            ProgressView("Загрузка цитаты…").tint(.white)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                Text(vm.loadFailureMessage ?? "Цитата пока не загружена.")
                    .multilineTextAlignment(.center)
                Button("Повторить") {
                    startAction { await vm.fetchNewQuote() }
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

    private func actionButtons(vm: QuoteViewModel) -> some View {
        VStack(spacing: 12) {
            Button {
                startAction { await vm.fetchNewQuote() }
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
                startAction { await vm.toggleFavorite() }
            } label: {
                HStack {
                    if vm.isSavingFavorite { ProgressView().tint(.white) }
                    Label(
                        vm.isFavorite ? "Убрать из избранного" : "В избранное",
                        systemImage: vm.isFavorite ? "heart.fill" : "heart"
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
        .disabled(actionTask != nil || vm.isLoading || vm.isSavingFavorite)
    }
}

#Preview {
    ContentView(services: AppServices(container: try! ModelContainer(
        for: FavoriteQuote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )))
}
