import Foundation
import SwiftUI

@MainActor
final class NotesListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var notes: [Note] = []

    private let repository: NoteRepository
    private let syncEngine: SyncEngine

    private var observer: FetchedResultsNotesObserver?

    init(repository: NoteRepository, syncEngine: SyncEngine) {
        self.repository = repository
        self.syncEngine = syncEngine
    }

    func bind(context: NSManagedObjectContext) {
        // Recreate observer whenever query changes (simple and reliable for small apps).
        observer = FetchedResultsNotesObserver(context: context, query: searchText) { [weak self] notes in
            DispatchQueue.main.async {
                self?.notes = notes
            }
        }
    }

    func updateQuery(context: NSManagedObjectContext) {
        bind(context: context)
    }

    func newNote() async throws -> Note {
        return try await repository.createNote(title: "", content: "")
    }

    func deleteNote(id: UUID) async throws {
        try await repository.deleteNote(id: id)
        await syncEngine.syncOnce()
    }

    func triggerSync() {
        Task { await syncEngine.syncOnce() }
    }
}
