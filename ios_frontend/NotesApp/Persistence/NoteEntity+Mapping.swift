import Foundation

extension NoteEntity {
    func toDomain() -> Note {
        Note(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            content: self.content ?? "",
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date(),
            isDeleted: self.isDeleted,
            lastSyncedAt: self.lastSyncedAt,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .dirty
        )
    }
}
