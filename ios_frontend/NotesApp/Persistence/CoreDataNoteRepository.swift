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

            // Local mutations always become dirty (awaiting push).
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

    func markNotesSyncing(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            for id in ids {
                guard let entity = try self.fetchEntity(id: id, context: ctx) else { continue }
                // Only transition to syncing from retryable states.
                let current = SyncStatus(rawValue: entity.syncStatus) ?? .dirty
                if current == .dirty || current == .failed {
                    entity.syncStatus = SyncStatus.syncing.rawValue
                }
            }
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    func markNotesClean(ids: [UUID], lastSyncedAt: Date) async throws {
        guard !ids.isEmpty else { return }
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            for id in ids {
                guard let entity = try self.fetchEntity(id: id, context: ctx) else { continue }
                entity.lastSyncedAt = lastSyncedAt
                entity.syncStatus = SyncStatus.clean.rawValue
            }
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    func markNotesFailed(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            for id in ids {
                guard let entity = try self.fetchEntity(id: id, context: ctx) else { continue }
                // If it was syncing, mark failed; if it's already dirty, keep it dirty (still needs push).
                let current = SyncStatus(rawValue: entity.syncStatus) ?? .dirty
                if current == .syncing {
                    entity.syncStatus = SyncStatus.failed.rawValue
                }
            }
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    func reconcileRemoteNotes(_ remoteNotes: [RemoteNote]) async throws {
        // Use a single reconciliation timestamp so all applied remote records share the same lastSyncedAt.
        let reconciliationTime = Date()

        let ctx = persistenceController.newBackgroundContext()
        try await ctx.perform {
            for remote in remoteNotes {
                let local = try self.fetchEntity(id: remote.id, context: ctx)

                if let local {
                    let localUpdated = local.updatedAt ?? .distantPast
                    let localStatus = SyncStatus(rawValue: local.syncStatus) ?? .dirty
                    let localHasUnsyncedChanges = (localStatus != .clean)

                    // Deterministic last-write-wins:
                    // - Newer updatedAt wins
                    // - On tie: prefer remote only if local is clean (no unsynced changes).
                    let shouldApplyRemote: Bool
                    if remote.updatedAt > localUpdated {
                        shouldApplyRemote = true
                    } else if remote.updatedAt < localUpdated {
                        shouldApplyRemote = false
                    } else {
                        // Tie: keep local if it has unsynced changes; otherwise accept remote.
                        shouldApplyRemote = !localHasUnsyncedChanges
                    }

                    if shouldApplyRemote {
                        local.title = remote.title
                        local.content = remote.content
                        local.createdAt = remote.createdAt
                        local.updatedAt = remote.updatedAt

                        // Tombstones are first-class: if remote says deleted, delete locally too.
                        local.isDeleted = remote.isDeleted

                        local.lastSyncedAt = reconciliationTime
                        local.syncStatus = SyncStatus.clean.rawValue
                    }
                } else {
                    // Remote note doesn't exist locally: insert it, including tombstones
                    // so future pulls preserve deletion knowledge (until you implement purge policies).
                    let entity = NoteEntity(context: ctx)
                    entity.id = remote.id
                    entity.title = remote.title
                    entity.content = remote.content
                    entity.createdAt = remote.createdAt
                    entity.updatedAt = remote.updatedAt
                    entity.isDeleted = remote.isDeleted
                    entity.lastSyncedAt = reconciliationTime
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
