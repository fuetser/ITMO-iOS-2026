import SwiftUI

struct EditFavoriteView: View {
    @Environment(\.dismiss) private var dismiss
    let favorite: FavoriteQuoteSnapshot
    @Bindable var viewModel: FavoritesViewModel
    @State private var draftNote: String
    @State private var saveTask: Task<Void, Never>?

    init(favorite: FavoriteQuoteSnapshot, viewModel: FavoritesViewModel) {
        self.favorite = favorite
        self.viewModel = viewModel
        _draftNote = State(initialValue: favorite.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Цитата") {
                    Text("«\(favorite.text)»").font(.body)
                    Text("— \(favorite.author)").font(.caption).foregroundStyle(.secondary)
                }
                Section("Заметка") {
                    TextField("Твоя заметка к цитате…", text: $draftNote, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(viewModel.isSaving || saveTask != nil)
                }
                Section {
                    Text("Добавлено: \(favorite.addedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.disabled(viewModel.isSaving || saveTask != nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Сохранить") {
                            guard saveTask == nil else { return }
                            let note = draftNote
                            saveTask = Task {
                                let saved = await viewModel.update(quoteId: favorite.id, note: note)
                                saveTask = nil
                                if saved, !Task.isCancelled {
                                    dismiss()
                                }
                            }
                        }
                        .bold()
                        .disabled(viewModel.isLoading || saveTask != nil)
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || saveTask != nil)
        .onDisappear { saveTask?.cancel() }
    }
}
