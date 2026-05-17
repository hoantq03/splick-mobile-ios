import Foundation
import CoreData
import Common

public final class CoreDataStack {
    public static let shared = CoreDataStack()

    public let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "SplickModel")

        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { description, error in
            if let error {
                Log.error("CoreData load failed: \(error)", category: .storage)
                fatalError("CoreData failed to load: \(error)")
            }
            Log.info("CoreData loaded: \(description.url?.absoluteString ?? "unknown")", category: .storage)
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    public func saveContext() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            Log.error("CoreData save failed: \(error)", category: .storage)
        }
    }
}
