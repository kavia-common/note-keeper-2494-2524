import Foundation

protocol NoteRepository {
    // PUBLIC_INTERFACE
    /// Creates a new note and persists it locally.
    func createNote(title: String, content: String) async throws -> Note

    // PUBLIC_INTERFACE
    /// Updates an existing note locally; marks it dirty for future sync.
    func upsertNote(_ note: Note) async throws

    // PUBLIC_INTERFACE
    /// Soft-deletes a note (tombstone) locally; marks it dirty for future sync.
    func deleteNote(id: UUID) async throws

    // PUBLIC_INTERFACE
    /// Loads notes matching an optional query (title/content contains, case/diacritic insensitive).
    func fetchNotes(query: String?) async throws -> [Note]

    // PUBLIC_INTERFACE
    /// Loads notes that need syncing (dirty/failed or never synced).
    func fetchDirtyNotes() async throws -> [Note]

    // PUBLIC_INTERFACE
    /// Marks notes as "syncing" prior to push so UI/business logic can differentiate in-flight vs dirty/failed.
    func markNotesSyncing(ids: [UUID]) async throws

    // PUBLIC_INTERFACE
    /// Marks notes as "clean" after a successful push and sets `lastSyncedAt` to the provided timestamp.
    func markNotesClean(ids: [UUID], lastSyncedAt: Date) async throws

    // PUBLIC_INTERFACE
    /// Marks notes as "failed" after a push attempt fails, so they remain eligible for retry.
    func markNotesFailed(ids: [UUID]) async throws

    // PUBLIC_INTERFACE
    /// Applies remote notes into the local store using last-write-wins by `updatedAt`.
    ///
    /// Determinism rules:
    /// - Compare by `updatedAt`.
    /// - If equal, prefer remote **only if** local is not dirty/syncing/failed (i.e., local has no unsynced changes).
    /// - Tombstones (`isDeleted == true`) are treated as normal updates and should win/lose by the same rules.
    func reconcileRemoteNotes(_ remoteNotes: [RemoteNote]) async throws
}
