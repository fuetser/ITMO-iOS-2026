import SwiftUI

struct ContentView: View {
    @State private var viewModel = QuoteViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        Text("«\(viewModel.currentQuote.text)»")
                            .font(.title2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)

                        Text("— \(viewModel.currentQuote.author)")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    Spacer()

                    Button(action: viewModel.fetchNewQuote) {
                        Label("Другая цитата", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(.white, in: Capsule())
                            .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Цитата дня")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
