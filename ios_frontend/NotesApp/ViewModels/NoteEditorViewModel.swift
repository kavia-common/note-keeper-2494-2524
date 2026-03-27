import Foundation

@MainActor
final class NoteEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var content: String

    private(set) var note: Note
    private let repository: NoteRepository
    private let syncEngine: SyncEngine

    init(note: Note, repository: NoteRepository, syncEngine: SyncEngine) {
        self.note = note
        self.repository = repository
        self.syncEngine = syncEngine
        self.title = note.title
        self.content = note.content
    }

    func save() async throws {
        var updated = note
        updated.title = title
        updated.content = content
        updated.updatedAt = Date()
        updated.isDeleted = false

        try await repository.upsertNote(updated)
        self.note = updated
        await syncEngine.syncOnce()
    }

    func delete() async throws {
        try await repository.deleteNote(id: note.id)
        await syncEngine.syncOnce()
    }
}
