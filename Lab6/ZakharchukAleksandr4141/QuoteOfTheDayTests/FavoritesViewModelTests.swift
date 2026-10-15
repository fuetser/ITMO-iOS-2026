import Foundation
import Testing

@testable import QuoteOfTheDay

@MainActor
struct FavoritesViewModelTests {
  @Test
  func noteSaveFailureReturnsFalse() async {
    let model = FavoritesViewModel(service: FavoritesServiceStub(updateError: StubError.failed))

    let saved = await model.updateNote(quoteId: UUID(), note: "My note")

    #expect(!saved)
    #expect(model.errorMessage?.hasPrefix("Не удалось сохранить заметку:") == true)
    #expect(!model.isSaving)
  }

  @Test
  func reloadFailureAfterNoteSaveStillReturnsTrue() async {
    let service = FavoritesServiceStub(fetchError: StubError.failed)
    let model = FavoritesViewModel(service: service)
    let quoteId = UUID()

    let saved = await model.updateNote(quoteId: quoteId, note: "My note")

    let notes = await service.updatedNotes
    #expect(saved)
    #expect(notes[quoteId] == "My note")
    let expectedPrefix = "Изменения сохранены, но не удалось обновить список:"
    #expect(model.errorMessage?.hasPrefix(expectedPrefix) == true)
    #expect(!model.isSaving)
  }

  @Test
  func cancelledLoadDoesNotShowError() async {
    let model = FavoritesViewModel(
      service: FavoritesServiceStub(fetchError: URLError(.cancelled))
    )

    await model.loadFavorites()

    #expect(model.errorMessage == nil)
    #expect(!model.hasLoaded)
    #expect(!model.isLoading)
  }

  @Test
  func repeatedDeletionAndNoteSaveAreIgnoredWhileDeleting() async {
    let service = FavoritesServiceStub()
    let gate = RequestGate()
    await service.suspendDeletion(on: gate)
    let model = FavoritesViewModel(service: service)
    let quoteId = UUID()

    let deletion = Task { await model.delete(quoteIds: [quoteId]) }
    await gate.waitUntilStarted()
    await model.deleteAll()
    let saved = await model.updateNote(quoteId: quoteId, note: "Ignored")
    let deleteCount = await service.deleteCount
    let notes = await service.updatedNotes

    #expect(deleteCount == 1)
    #expect(!saved)
    #expect(notes.isEmpty)
    #expect(model.isSaving)
    await gate.release()
    await deletion.value
    #expect(!model.isSaving)
    #expect(model.hasLoaded)
  }
}
