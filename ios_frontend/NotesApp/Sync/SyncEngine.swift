import Foundation
import Combine

final class SyncEngine {
    private let repository: NoteRepository
    private let remoteAPI: RemoteNotesAPI
    private let networkMonitor: NetworkMonitor

    private var cancellables: Set<AnyCancellable> = []
    private var isStarted = false

    // Retry/backoff state
    private var inFlightSyncTask: Task<Void, Never>?
    private var scheduledRetryTask: Task<Void, Never>?
    private var consecutiveFailureCount: Int = 0

    // Backoff tuning (kept conservative for a small app scaffold)
    private let baseRetryDelaySeconds: TimeInterval = 2
    private let maxRetryDelaySeconds: TimeInterval = 60
    private let maxConsecutiveFailuresBeforeMaxDelayClamp: Int = 10

    init(repository: NoteRepository, remoteAPI: RemoteNotesAPI, networkMonitor: NetworkMonitor) {
        self.repository = repository
        self.remoteAPI = remoteAPI
        self.networkMonitor = networkMonitor
    }

    deinit {
        inFlightSyncTask?.cancel()
        scheduledRetryTask?.cancel()
    }

    // PUBLIC_INTERFACE
    /// Starts observing connectivity and triggers sync when online.
    ///
    /// Step 01.05 behavior:
    /// - If a sync fails, schedule a retry using exponential backoff.
    /// - If connectivity is regained while a retry is scheduled, cancel the delay and retry immediately.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        networkMonitor.$isOnline
            .removeDuplicates()
            .sink { [weak self] online in
                guard let self else { return }
                if online {
                    // Connectivity regained: if we were waiting on a backoff delay, retry immediately.
                    self.cancelScheduledRetry()
                    self.triggerSync(reason: "connectivity_regained")
                } else {
                    // If we go offline, cancel any in-flight network work and keep scheduled retry paused.
                    // (We'll retry immediately on reconnect.)
                    self.inFlightSyncTask?.cancel()
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
    ///   - On failure: mark them failed (retryable) (or keep dirty if already dirty).
    /// - Pull phase:
    ///   - Pull remote notes and reconcile locally via deterministic last-write-wins.
    ///
    /// Step 01.05 additions:
    /// - On failure: schedule exponential backoff retry (only when online).
    /// - On connectivity regained: immediately retry any pending work.
    func syncOnce() async {
        await performSyncAttempt(allowSchedulingRetry: true)
    }

    // MARK: - Internal orchestration

    private func triggerSync(reason: String) {
        // Avoid parallel sync passes; for a small app, a single serialized pipeline is simplest.
        guard inFlightSyncTask == nil else { return }

        inFlightSyncTask = Task { [weak self] in
            guard let self else { return }
            defer { self.inFlightSyncTask = nil }

            // If this is a manual/triggered attempt, we allow retry scheduling too.
            await self.performSyncAttempt(allowSchedulingRetry: true)
        }
    }

    private func cancelScheduledRetry() {
        scheduledRetryTask?.cancel()
        scheduledRetryTask = nil
    }

    private func scheduleRetryWithBackoff() {
        // If we're offline, don't schedule timers; we'll retry on connectivity regained.
        guard networkMonitor.isOnline else { return }

        // Don't stack multiple scheduled retries.
        guard scheduledRetryTask == nil else { return }

        let failureCountForDelay = min(consecutiveFailureCount, maxConsecutiveFailuresBeforeMaxDelayClamp)
        let delay = min(maxRetryDelaySeconds, baseRetryDelaySeconds * pow(2, Double(max(0, failureCountForDelay - 1))))

        scheduledRetryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // Cancelled (likely due to connectivity regained or app lifecycle).
                return
            }

            await MainActor.run {
                self.scheduledRetryTask = nil
                // Retry after delay; if we're offline by then, start()'s connectivity callback will handle it.
                self.triggerSync(reason: "scheduled_retry")
            }
        }
    }

    private func performSyncAttempt(allowSchedulingRetry: Bool) async {
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

            // Success => clear backoff state.
            consecutiveFailureCount = 0
            cancelScheduledRetry()
        } catch {
            // On failure: ensure items remain eligible for retry by transitioning syncing -> failed.
            // Notes that are already dirty should remain dirty (repository enforces this).
            await markCurrentDirtyBatchAsFailedBestEffort()

            // Increase failure count and schedule backoff retry.
            consecutiveFailureCount += 1

            if allowSchedulingRetry {
                // If we are offline, we don't schedule a timer; we'll retry on connectivity regained.
                scheduleRetryWithBackoff()
            }

            // Keep scaffold behavior: swallow errors (no UI surfacing yet).
            _ = error
        }
    }

    private func markCurrentDirtyBatchAsFailedBestEffort() async {
        do {
            let dirty = try await repository.fetchDirtyNotes()
            try await repository.markNotesFailed(ids: dirty.map(\.id))
        } catch {
            // no-op: we tried our best to set failure state.
        }
    }
}
