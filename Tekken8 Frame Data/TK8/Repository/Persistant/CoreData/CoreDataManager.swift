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
    
    func deleteAll() throws {
        // 삭제할 엔티티 이름들을 배열로 관리
        let entityNames = [Text.character, Text.move]
        
        for name in entityNames {
            // 1) NSFetchRequest<Result> 생성
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: name)
            
            // 2) Batch Delete Request 생성
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            // 삭제된 객체의 ObjectID를 반환받아 컨텍스트에 머지하기 위함
            batchDelete.resultType = .resultTypeObjectIDs
            
            // 3) 실행
            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            
            // 4) 컨텍스트에 변경사항 머지
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        }
        // 5) 저장
        try saveContext()
    }
}

private extension CoreDataManager {
    enum Text {
        static let containerName = "Tekken8FrameData"
        static let character = "CharacterEntity"
        static let move = "MoveEntity"
    }
}
