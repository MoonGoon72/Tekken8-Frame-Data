//
//  InMemoryCoreDataManager.swift
//  TK8Tests
//

@testable import TK8
import CoreData

final class InMemoryCoreDataManager: CoreDataManageable {
    let context: NSManagedObjectContext
    var saveError: Error?
    @MainActor private(set) var frameDataGeneration = 0
    @MainActor var isReplacingFrameData = false

    @MainActor
    func replaceFrameData(characters: [Character], moves: [Move]) async throws {
        isReplacingFrameData = true
        defer { isReplacingFrameData = false }
        try await saveFrameDataSnapshot(characters: characters, moves: moves)
        frameDataGeneration += 1
    }

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
        if let saveError { throw saveError }
        if context.hasChanges { try context.save() }
    }

    func fetch<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>) throws -> [Entity] {
        try context.fetch(request)
    }

    func delete(_ object: NSManagedObject) {
        context.delete(object)
    }

}
