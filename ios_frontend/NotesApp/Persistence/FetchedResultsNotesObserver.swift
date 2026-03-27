import CoreData
import Foundation

final class FetchedResultsNotesObserver: NSObject, NSFetchedResultsControllerDelegate {
    private let fetchedResultsController: NSFetchedResultsController<NoteEntity>
    private let onChange: ([Note]) -> Void

    init(context: NSManagedObjectContext, query: String?, onChange: @escaping ([Note]) -> Void) {
        self.onChange = onChange

        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        // Keep predicate consistent with repository.
        let notDeleted = NSPredicate(format: "isDeleted == NO")
        if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            let title = NSPredicate(format: "title CONTAINS[cd] %@", q)
            let content = NSPredicate(format: "content CONTAINS[cd] %@", q)
            let matches = NSCompoundPredicate(orPredicateWithSubpredicates: [title, content])
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notDeleted, matches])
        } else {
            request.predicate = notDeleted
        }

        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        super.init()
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
            let notes = (fetchedResultsController.fetchedObjects ?? []).map { $0.toDomain() }
            onChange(notes)
        } catch {
            onChange([])
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        let notes = (fetchedResultsController.fetchedObjects ?? []).map { $0.toDomain() }
        onChange(notes)
    }
}
