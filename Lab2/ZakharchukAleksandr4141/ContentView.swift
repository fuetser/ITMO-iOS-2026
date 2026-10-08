import SwiftUI

struct ContentView: View {
    @State private var randomNumber: Int?

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 20) {
                Text(randomNumber.map { String($0) } ?? "Случайное число")
                    .font(.largeTitle)

                Button("Показать случайное число") {
                    randomNumber = Int.random(in: 1...100)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Открыть второй экран") {
                    SecondScreenView()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Первый экран")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SecondScreenView: View {
    var body: some View {
        Text("Второй экран")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Второй экран")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
