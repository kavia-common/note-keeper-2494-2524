import Foundation
import UIKit

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Background sync scheduling using iOS BGTaskScheduler (iOS 13+).
///
/// Important: This requires adding the task identifier to Info.plist:
/// `BGTaskSchedulerPermittedIdentifiers` includes `com.notekeeper.notesapp.sync.refresh`
/// (see ios_frontend/README.md for details).
final class BGTaskBackgroundSyncScheduler: BackgroundSyncScheduling {
    /// Keep this stable; it must match Info.plist `BGTaskSchedulerPermittedIdentifiers`.
    static let taskIdentifier = "com.notekeeper.notesapp.sync.refresh"

    private let onPerformSync: () async -> Void

    /// - Parameter onPerformSync: async callback to perform a best-effort sync.
    init(onPerformSync: @escaping () async -> Void) {
        self.onPerformSync = onPerformSync
    }

    func configure() {
        guard Self.isSupported else { return }

        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }
        #endif
    }

    func schedulePeriodicSync(earliestBegin: TimeInterval) {
        guard Self.isSupported else { return }

        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: max(60, earliestBegin))

        do {
            // Replace any existing request with a new one (best-effort).
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Non-fatal: background scheduling is optional. App continues to work via foreground sync.
            _ = error
        }
        #endif
    }

    func cancel() {
        guard Self.isSupported else { return }
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        #endif
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Always schedule the next one first to keep periodicity.
        schedulePeriodicSync(earliestBegin: 15 * 60)

        let work = Task { [onPerformSync] in
            await onPerformSync()
        }

        task.expirationHandler = {
            work.cancel()
        }

        Task {
            _ = await work.result
            task.setTaskCompleted(success: !work.isCancelled)
        }
    }

    private static var isSupported: Bool {
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }
}

/// Simple factory to select the best available scheduler while preserving a no-op fallback.
enum BackgroundSyncSchedulerFactory {
    // PUBLIC_INTERFACE
    /// Creates the best available background scheduler for this runtime.
    ///
    /// If BGTaskScheduler isn't supported (older iOS) or the target doesn't include BackgroundTasks,
    /// this returns a no-op scheduler.
    static func make(onPerformSync: @escaping () async -> Void) -> BackgroundSyncScheduling {
        if #available(iOS 13.0, *) {
            #if canImport(BackgroundTasks)
            return BGTaskBackgroundSyncScheduler(onPerformSync: onPerformSync)
            #else
            return NoopBackgroundSyncScheduler()
            #endif
        } else {
            return NoopBackgroundSyncScheduler()
        }
    }
}
