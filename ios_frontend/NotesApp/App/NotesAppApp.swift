import SwiftUI

@main
struct NotesAppApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let appEnvironment: AppEnvironment
    private let backgroundSyncScheduler: BackgroundSyncScheduling

    init() {
        let persistence = PersistenceController.shared
        let repository = CoreDataNoteRepository(persistenceController: persistence)
        let networkMonitor = NetworkMonitor()

        // Dependency injection decision:
        // - Default to MockRemoteNotesAPI in DEBUG for a "no-backend-required" dev experience.
        // - Optionally enable URLSessionRemoteNotesAPI by providing a base URL.
        let remoteAPI: RemoteNotesAPI = Self.makeRemoteNotesAPI()

        let syncEngine = SyncEngine(repository: repository, remoteAPI: remoteAPI, networkMonitor: networkMonitor)

        // Step 01.02:
        // Background sync scheduling is optional. We use a plugin-style abstraction with a no-op fallback
        // so the app remains functional even when BGTaskScheduler isn't available/configured.
        let scheduler = BackgroundSyncSchedulerFactory.make {
            await syncEngine.syncOnce()
        }
        scheduler.configure()

        self.backgroundSyncScheduler = scheduler
        self.appEnvironment = AppEnvironment(
            persistenceController: persistence,
            noteRepository: repository,
            syncEngine: syncEngine,
            networkMonitor: networkMonitor
        )
    }

    var body: some Scene {
        WindowGroup {
            NotesListView(
                viewModel: NotesListViewModel(
                    repository: appEnvironment.noteRepository,
                    syncEngine: appEnvironment.syncEngine
                )
            )
            .environment(\.managedObjectContext, appEnvironment.persistenceController.container.viewContext)
            .onAppear {
                // Start connectivity observation and do an initial sync attempt (no-op if offline or mock).
                appEnvironment.syncEngine.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Step 01.06:
                // Trigger a best-effort sync when the app becomes active.
                // `SyncEngine` already guards against parallel syncs and no-ops when offline.
                guard newPhase == .active else { return }

                // Foreground sync (primary behavior, always available).
                Task { await appEnvironment.syncEngine.syncOnce() }

                // Step 01.02: Also refresh background schedule (best-effort).
                // If unsupported or not configured, this is a no-op.
                backgroundSyncScheduler.schedulePeriodicSync(earliestBegin: 15 * 60)
            }
        }
    }

    // MARK: - Remote API selection

    // PUBLIC_INTERFACE
    /// Creates the `RemoteNotesAPI` used by the app.
    ///
    /// In this scaffold we keep configuration simple:
    /// - DEBUG: use `MockRemoteNotesAPI()` by default
    /// - RELEASE: use `MockRemoteNotesAPI()` unless you set a URL below
    ///
    /// To point at a backend, set `remoteBaseURLString` to something like:
    /// "https://example.com/api"
    static func makeRemoteNotesAPI() -> RemoteNotesAPI {
        // NOTE: Request from user/orchestrator if you want this configurable via build settings or Info.plist.
        let remoteBaseURLString: String? = nil

        if let remoteBaseURLString,
           let url = URL(string: remoteBaseURLString) {
            return URLSessionRemoteNotesAPI(baseURL: url)
        }

        #if DEBUG
        return MockRemoteNotesAPI()
        #else
        // Keep a safe default for now until a backend exists.
        return MockRemoteNotesAPI()
        #endif
    }
}

/// Central object holding long-lived dependencies.
/// Kept minimal so we don't leak Core Data details into Views.
struct AppEnvironment {
    let persistenceController: PersistenceController
    let noteRepository: NoteRepository
    let syncEngine: SyncEngine
    let networkMonitor: NetworkMonitor
}
