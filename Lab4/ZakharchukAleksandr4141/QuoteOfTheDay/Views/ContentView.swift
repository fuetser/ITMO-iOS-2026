//
//  ContentView.swift
//  QuoteOfTheDay
//

import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: QuoteViewModel?
    @State private var showFavorites = false

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
                    .disabled(viewModel == nil)
                }
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView()
            }
            .alert(
                "Ошибка",
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
                viewModel = QuoteViewModel(context: modelContext)
            }
        }
    }

    @ViewBuilder
    private func content(vm: QuoteViewModel) -> some View {
        VStack(spacing: 24) {
            Spacer()
            quoteCard(vm: vm)
            Spacer()
            actionButtons(vm: vm)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    private func quoteCard(vm: QuoteViewModel) -> some View {
        VStack(spacing: 16) {
            Text("«\(vm.currentQuote.text)»")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .animation(.easeInOut, value: vm.currentQuote)

            Text("— \(vm.currentQuote.author)")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 8)
    }

    private func actionButtons(vm: QuoteViewModel) -> some View {
        VStack(spacing: 12) {
            Button(action: vm.fetchNewQuote) {
                Label("Другая цитата", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: vm.toggleFavorite) {
                Label(
                    vm.isFavorite ? "Убрать из избранного" : "В избранное",
                    systemImage: vm.isFavorite ? "heart.fill" : "heart"
                )
                .font(.headline)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FavoriteQuote.self, inMemory: true)
}
