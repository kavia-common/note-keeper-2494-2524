import SwiftUI

@main
struct NotesAppApp: App {
    private let appEnvironment: AppEnvironment

    init() {
        let persistence = PersistenceController.shared
        let repository = CoreDataNoteRepository(persistenceController: persistence)
        let networkMonitor = NetworkMonitor()
        let remoteAPI = MockRemoteNotesAPI()
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
}

/// Central object holding long-lived dependencies.
/// Kept minimal so we don't leak Core Data details into Views.
struct AppEnvironment {
    let persistenceController: PersistenceController
    let noteRepository: NoteRepository
    let syncEngine: SyncEngine
    let networkMonitor: NetworkMonitor
}
