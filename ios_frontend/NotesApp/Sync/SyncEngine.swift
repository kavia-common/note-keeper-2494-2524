import Foundation
import Combine

final class SyncEngine {
    private let repository: NoteRepository
    private let remoteAPI: RemoteNotesAPI
    private let networkMonitor: NetworkMonitor

    private var cancellables: Set<AnyCancellable> = []
    private var isStarted = false

    init(repository: NoteRepository, remoteAPI: RemoteNotesAPI, networkMonitor: NetworkMonitor) {
        self.repository = repository
        self.remoteAPI = remoteAPI
        self.networkMonitor = networkMonitor
    }

    // PUBLIC_INTERFACE
    /// Starts observing connectivity and triggers sync when online.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        networkMonitor.$isOnline
            .removeDuplicates()
            .sink { [weak self] online in
                guard let self else { return }
                if online {
                    Task { await self.syncOnce() }
                }
            }
            .store(in: &cancellables)
    }

    // PUBLIC_INTERFACE
    /// Attempts a single sync pass (push then pull). Safe to call repeatedly.
    ///
    /// Sync behavior:
    /// - Push phase:
    ///   - Fetch non-clean notes (dirty/syncing/failed).
    ///   - Mark them syncing.
    ///   - Push to remote (including tombstones).
    ///   - On success: mark them clean and set lastSyncedAt to a single, consistent timestamp.
    ///   - On failure: mark them failed (retryable).
    /// - Pull phase:
    ///   - Pull remote notes and reconcile locally via deterministic last-write-wins.
    func syncOnce() async {
        guard networkMonitor.isOnline else { return }

        // Push then pull (simple, predictable for small apps).
        do {
            let dirty = try await repository.fetchDirtyNotes()
            let idsToPush = dirty.map(\.id)

            // Mark syncing before the network call (explicit state transition).
            try await repository.markNotesSyncing(ids: idsToPush)

            let remoteDirty = dirty.map {
                RemoteNote(
                    id: $0.id,
                    title: $0.title,
                    content: $0.content,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isDeleted: $0.isDeleted
                )
            }

            try await remoteAPI.pushNotes(remoteDirty)

            // After a successful push, mark as clean and set lastSyncedAt consistently.
            let pushedAt = Date()
            try await repository.markNotesClean(ids: idsToPush, lastSyncedAt: pushedAt)

            // Pull remote notes and reconcile locally with deterministic last-write-wins (incl tombstones).
            let remoteNotes = try await remoteAPI.pullNotes()
            try await repository.reconcileRemoteNotes(remoteNotes)
        } catch {
            // Mark the current batch as failed to keep it retryable on next sync attempt.
            // Note: if fetchDirtyNotes() throws, idsToPush is unknown; in that case we do nothing.
            do {
                let dirty = try await repository.fetchDirtyNotes()
                try await repository.markNotesFailed(ids: dirty.map(\.id))
            } catch {
                // no-op: we tried our best to set failure state.
            }

            // Keep scaffold behavior: swallow errors (no UI surfacing yet).
            _ = error
        }
    }
}
