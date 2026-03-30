import SwiftUI

@main
struct NotesAppApp: App {
    private let appEnvironment: AppEnvironment

    init() {
        let persistence = PersistenceController.shared
        let repository = CoreDataNoteRepository(persistenceController: persistence)
        let networkMonitor = NetworkMonitor()

        // Dependency injection decision:
        // - Default to MockRemoteNotesAPI in DEBUG for a "no-backend-required" dev experience.
        // - Optionally enable URLSessionRemoteNotesAPI by providing a base URL.
        let remoteAPI: RemoteNotesAPI = Self.makeRemoteNotesAPI()

        let syncEngine = SyncEngine(repository: repository, remoteAPI: remoteAPI, networkMonitor: networkMonitor)

        self.appEnvironment = AppEnvironment(
            persistenceController: persistence,
            noteRepository: repository,
            syncEngine: syncEngine,
            networkMonitor: networkMonitor
        )
    }

    var body: some Scene {
        WindowGroup {
            NotesListView(viewModel: NotesListViewModel(repository: appEnvironment.noteRepository,
                                                        syncEngine: appEnvironment.syncEngine))
            .environment(\.managedObjectContext, appEnvironment.persistenceController.container.viewContext)
            .onAppear {
                // Kick off initial sync attempt (no-op if offline or mock).
                appEnvironment.syncEngine.start()
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
