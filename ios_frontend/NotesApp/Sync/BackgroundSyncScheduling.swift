import Foundation

/// Abstraction for scheduling background sync, designed to be optional.
///
/// The app must remain fully functional without background scheduling (sync-on-resume still works),
/// so implementations should gracefully fail and callers should treat failures as non-fatal.
protocol BackgroundSyncScheduling {
    // PUBLIC_INTERFACE
    /// Configure any system hooks required for background scheduling.
    ///
    /// Call this early in app startup (e.g., in `App.init()`), before scheduling tasks.
    func configure()

    // PUBLIC_INTERFACE
    /// Requests/refreshes a periodic background sync schedule.
    ///
    /// - Parameter earliestBegin: An earliest-begin hint; implementations may ignore or clamp.
    func schedulePeriodicSync(earliestBegin: TimeInterval)

    // PUBLIC_INTERFACE
    /// Cancels any previously scheduled background sync.
    func cancel()
}

/// No-op fallback used when background scheduling is unavailable or not configured.
/// This ensures the app remains functional (sync-on-resume and manual sync still work).
final class NoopBackgroundSyncScheduler: BackgroundSyncScheduling {
    func configure() {}
    func schedulePeriodicSync(earliestBegin: TimeInterval) {}
    func cancel() {}
}
