//
//  InMemoryCoreDataManager.swift
//  TK8Tests
//

@testable import TK8
import CoreData

final class InMemoryCoreDataManager: CoreDataManageable {
    let context: NSManagedObjectContext

    init() {
        let container = NSPersistentContainer(name: "Tekken8FrameData")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { fatalError("In-memory store 초기화 실패: \(error)") }
        }
        context = container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveContext() throws {
        if context.hasChanges { try context.save() }
    }

    func fetch<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>) throws -> [Entity] {
        try context.fetch(request)
    }

    func delete(_ object: NSManagedObject) {
        context.delete(object)
    }

    func deleteAll() throws {}
}
