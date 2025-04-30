//
//  CoreDataManager.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

final class CoreDataManager: CoreDataManageable {
    let context: NSManagedObjectContext
    
    init() {
        let container = NSPersistentContainer(name: Text.containerName)
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data load 실패: \(error)")
            }
        }
        context = container.viewContext
    }
    
    func saveContext() throws {
        if context.hasChanges { try context.save() }
    }
    
    func fetch<Entity>(_ request: NSFetchRequest<Entity>) throws -> [Entity] where Entity : NSManagedObject {
        try context.fetch(request)
    }
    
    func delete(_ object: NSManagedObject) {
        context.delete(object)
    }
}

private extension CoreDataManager {
    enum Text {
        static let containerName = "Tekken8FrameData"
    }
}
