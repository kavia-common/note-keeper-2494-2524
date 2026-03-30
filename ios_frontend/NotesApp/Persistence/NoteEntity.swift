import CoreData
import Foundation

@objc(NoteEntity)
final class NoteEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var content: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var isDeleted: Bool
    @NSManaged var lastSyncedAt: Date?
    @NSManaged var syncStatus: Int16
}

extension NoteEntity {
    // PUBLIC_INTERFACE
    /// Provides the Core Data fetch request for `NoteEntity`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }
}
