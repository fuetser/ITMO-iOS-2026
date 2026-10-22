import Foundation
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
      noteForm
        .navigationTitle("Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .alert("Ошибка", isPresented: isErrorPresented) {
          Button("OK") { viewModel.errorMessage = nil }
        } message: {
          Text(viewModel.errorMessage ?? "")
        }
    }
    .interactiveDismissDisabled(isClosingDisabled)
    .onDisappear { saveTask?.cancel() }
  }

  private var noteForm: some View {
    Form {
      Section("Цитата") {
        Text("«\(favorite.text)»").font(.body)
        Text("— \(favorite.author)").font(.caption).foregroundStyle(.secondary)
      }
      Section("Заметка") {
        TextField("Твоя заметка к цитате…", text: $draftNote, axis: .vertical)
          .lineLimit(3...6)
          .disabled(isClosingDisabled)
      }
      Section {
        Text("Добавлено: \(favorite.addedAt.formatted(date: .abbreviated, time: .shortened))")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  @ToolbarContentBuilder
  private var editorToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button("Отмена") { dismiss() }
        .disabled(isClosingDisabled)
    }
    ToolbarItem(placement: .topBarTrailing) {
      if viewModel.isSaving {
        ProgressView()
      } else {
        Button("Сохранить") { saveNote() }
          .bold()
          .disabled(isSaveButtonDisabled)
      }
    }
  }

  private var isClosingDisabled: Bool {
    viewModel.isSaving || saveTask != nil
  }

  private var isSaveButtonDisabled: Bool {
    viewModel.isLoading || saveTask != nil
  }

  private var isErrorPresented: Binding<Bool> {
    Binding(
      get: { viewModel.errorMessage != nil },
      set: { isPresented in
        if !isPresented { viewModel.errorMessage = nil }
      }
    )
  }

  private func saveNote() {
    guard saveTask == nil else { return }
    // Передаём снимок введённого текста: задача сохраняет именно эту версию заметки.
    let note = draftNote
    saveTask = Task {
      let saved = await viewModel.updateNote(quoteId: favorite.id, note: note)
      saveTask = nil
      if saved, !Task.isCancelled {
        dismiss()
      }
    }
  }
}
