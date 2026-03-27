import CoreData
import Foundation

final class CoreDataNoteRepository: NoteRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func createNote(title: String, content: String) async throws -> Note {
        let now = Date()
        let id = UUID()

        let ctx = persistenceController.newBackgroundContext()
        return try await ctx.perform {
            let entity = NoteEntity(context: ctx)
            entity.id = id
            entity.title = title
            entity.content = content
            entity.createdAt = now
            entity.updatedAt = now
            entity.isDeleted = false
            entity.lastSyncedAt = nil
            entity.syncStatus = SyncStatus.dirty.rawValue

            try ctx.save()
            return entity.toDomain()
        }
    }

    func upsertNote(_ note: Note) async throws {
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            let entity = try self.fetchEntity(id: note.id, context: ctx) ?? NoteEntity(context: ctx)
            entity.id = note.id
            entity.title = note.title
            entity.content = note.content
            entity.createdAt = note.createdAt
            entity.updatedAt = note.updatedAt
            entity.isDeleted = note.isDeleted

            // Dirty if modified after last sync.
            entity.syncStatus = SyncStatus.dirty.rawValue

            try ctx.save()
        }
    }

    func deleteNote(id: UUID) async throws {
        let now = Date()
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            guard let entity = try self.fetchEntity(id: id, context: ctx) else { return }
            entity.isDeleted = true
            entity.updatedAt = now
            entity.syncStatus = SyncStatus.dirty.rawValue
            try ctx.save()
        }
    }

    func fetchNotes(query: String?) async throws -> [Note] {
        let ctx = persistenceController.container.viewContext
        return try await ctx.perform {
            let req: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            req.predicate = Self.notesPredicate(query: query)

            let results = try ctx.fetch(req)
            return results.map { $0.toDomain() }
        }
    }

    func fetchDirtyNotes() async throws -> [Note] {
        let ctx = persistenceController.container.viewContext
        return try await ctx.perform {
            let req: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "syncStatus != %d", SyncStatus.clean.rawValue),
                NSPredicate(format: "id != nil")
            ])

            let results = try ctx.fetch(req)
            return results.map { $0.toDomain() }
        }
    }

    func reconcileRemoteNotes(_ remoteNotes: [RemoteNote]) async throws {
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            for remote in remoteNotes {
                let local = try self.fetchEntity(id: remote.id, context: ctx)

                if let local {
                    // Last-write-wins (prefer remote on tie).
                    let localUpdated = local.updatedAt ?? .distantPast
                    if remote.updatedAt >= localUpdated {
                        local.title = remote.title
                        local.content = remote.content
                        local.createdAt = remote.createdAt
                        local.updatedAt = remote.updatedAt
                        local.isDeleted = remote.isDeleted
                        local.lastSyncedAt = Date()
                        local.syncStatus = SyncStatus.clean.rawValue
                    }
                } else {
                    let entity = NoteEntity(context: ctx)
                    entity.id = remote.id
                    entity.title = remote.title
                    entity.content = remote.content
                    entity.createdAt = remote.createdAt
                    entity.updatedAt = remote.updatedAt
                    entity.isDeleted = remote.isDeleted
                    entity.lastSyncedAt = Date()
                    entity.syncStatus = SyncStatus.clean.rawValue
                }
            }

            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    private func fetchEntity(id: UUID, context: NSManagedObjectContext) throws -> NoteEntity? {
        let req: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(req).first
    }

    private static func notesPredicate(query: String?) -> NSPredicate {
        let notDeleted = NSPredicate(format: "isDeleted == NO")
        guard let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty else {
            return notDeleted
        }
        let title = NSPredicate(format: "title CONTAINS[cd] %@", q)
        let content = NSPredicate(format: "content CONTAINS[cd] %@", q)
        let matches = NSCompoundPredicate(orPredicateWithSubpredicates: [title, content])
        return NSCompoundPredicate(andPredicateWithSubpredicates: [notDeleted, matches])
    }
}
