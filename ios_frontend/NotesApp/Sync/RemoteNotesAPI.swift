import Foundation

struct RemoteNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
}

protocol RemoteNotesAPI {
    // PUBLIC_INTERFACE
    /// Pulls notes from the remote backend. Backend shape is not specified; this is an abstraction.
    func pullNotes() async throws -> [RemoteNote]

    // PUBLIC_INTERFACE
    /// Pushes local notes (including tombstones) to the remote backend.
    func pushNotes(_ notes: [RemoteNote]) async throws
}

final class MockRemoteNotesAPI: RemoteNotesAPI {
    func pullNotes() async throws -> [RemoteNote] {
        // Placeholder: no backend configured.
        return []
    }

    func pushNotes(_ notes: [RemoteNote]) async throws {
        // Placeholder: no backend configured.
        _ = notes
    }
}
