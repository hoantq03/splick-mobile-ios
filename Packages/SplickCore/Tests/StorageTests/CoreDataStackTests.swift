import XCTest
import CoreData
@testable import Storage
@testable import Common

final class CoreDataStackTests: XCTestCase {
    func testCoreDataStackWithInMemoryContainer() {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "TestItem"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let titleAttribute = NSAttributeDescription()
        titleAttribute.name = "title"
        titleAttribute.attributeType = .stringAttributeType
        titleAttribute.isOptional = true

        entity.properties = [idAttribute, titleAttribute]
        model.entities = [entity]

        let container = NSPersistentContainer(name: "TestSplickModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let exp = expectation(description: "loadStores")
        container.loadPersistentStores { desc, error in
            XCTAssertNil(error)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let stack = CoreDataStack(container: container)

        // viewContext & newBackgroundContext
        let viewCtx = stack.viewContext
        XCTAssertNotNil(viewCtx)

        let bgCtx = stack.newBackgroundContext()
        XCTAssertNotNil(bgCtx)
        XCTAssertNotNil(bgCtx.mergePolicy)

        // saveContext when no changes
        stack.saveContext()

        // Insert an object and saveContext
        let item = NSEntityDescription.insertNewObject(forEntityName: "TestItem", into: viewCtx)
        item.setValue(UUID(), forKey: "id")
        item.setValue("Sample Item", forKey: "title")
        XCTAssertTrue(viewCtx.hasChanges)

        stack.saveContext()
        XCTAssertFalse(viewCtx.hasChanges)
    }

    func testCoreDataStackConvenienceInitAndShared() {
        let memoryStack = CoreDataStack(name: "TestModelInMemory", inMemory: true)
        XCTAssertNotNil(memoryStack.viewContext)

        let diskStack = CoreDataStack(name: "TestModelDisk", inMemory: false)
        XCTAssertNotNil(diskStack.viewContext)

        _ = CoreDataStack.shared
    }

    func testSaveContextFailure() {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "StrictItem"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let nonOptionalAttr = NSAttributeDescription()
        nonOptionalAttr.name = "requiredNonNil"
        nonOptionalAttr.attributeType = .stringAttributeType
        nonOptionalAttr.isOptional = false

        entity.properties = [nonOptionalAttr]
        model.entities = [entity]

        let container = NSPersistentContainer(name: "StrictModel", managedObjectModel: model)
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, _ in }

        let stack = CoreDataStack(container: container)
        _ = NSEntityDescription.insertNewObject(forEntityName: "StrictItem", into: stack.viewContext)

        // Saving without requiredNonNil will fail validation and throw, hitting catch { Log.error(...) }
        stack.saveContext()
    }
}
