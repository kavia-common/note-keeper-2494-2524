import Foundation

struct Note: Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var lastSyncedAt: Date?
    var syncStatus: SyncStatus

    var previewText: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}

enum SyncStatus: Int16, Equatable {
    case clean = 0
    case dirty = 1
    case syncing = 2
    case failed = 3
}
