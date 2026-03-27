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
    func syncOnce() async {
        guard networkMonitor.isOnline else { return }

        do {
            // Push dirty notes
            let dirty = try await repository.fetchDirtyNotes()
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

            // Pull remote notes and reconcile locally with last-write-wins
            let remoteNotes = try await remoteAPI.pullNotes()
            try await repository.reconcileRemoteNotes(remoteNotes)
        } catch {
            // For now, swallow errors. A real implementation should mark syncStatus=failed and backoff.
            // Kept minimal per scaffold requirement.
            _ = error
        }
    }
}
