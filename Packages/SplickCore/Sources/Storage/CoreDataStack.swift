import Foundation
import CoreData
import Common

public final class CoreDataStack {
    public static let shared = CoreDataStack()

    public let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public convenience init(name: String = "SplickModel", bundle: Bundle? = nil, inMemory: Bool = false) {
        let container: NSPersistentContainer
        let searchBundle = bundle ?? Bundle.main
        if let modelURL = searchBundle.url(forResource: name, withExtension: "momd") ?? searchBundle.url(forResource: name, withExtension: "mom"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            container = NSPersistentContainer(name: name, managedObjectModel: model)
        } else {
            let emptyModel = NSManagedObjectModel()
            container = NSPersistentContainer(name: name, managedObjectModel: emptyModel)
        }

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        if inMemory {
            description.type = NSInMemoryStoreType
        }
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            if let error {
                Log.error("CoreData load failed: \(error)", category: .storage)
            } else {
                Log.info("CoreData loaded: \(description.url?.absoluteString ?? "unknown")", category: .storage)
            }
        }

        self.init(container: container)
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
