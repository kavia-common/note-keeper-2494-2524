import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // NOTE: This expects a Core Data model named "NotesApp".
        container = NSPersistentContainer(name: "NotesApp")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}
