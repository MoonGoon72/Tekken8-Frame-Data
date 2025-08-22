//
//  DefaultMoveRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import CoreData

final class DefaultMoveRepository: MoveRepository {
    private let manager: SupabaseManageable
    private let coreData: CoreDataManageable
    
    init(manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.manager = manager
        self.coreData = coreData
    }
    
    func fetchMoves(characterName name: String) async throws -> [Move] {
        let request = MoveEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "command", ascending: true)]
        request.predicate = NSPredicate(format: "characterName == %@", name)
        
        if let result = try? coreData.fetch(request), !result.isEmpty {
            return result.map({ MoveDTO(entity: $0).toDomain() })
        }
        
        let fetchedMoves = try await manager.fetchMoves(characterName: name)
        try addToCoreData(fetchedMoves)
        
        return fetchedMoves
    }
    
    private func addToCoreData(_ data: [Move]) throws {
        let context = coreData.context
        let moveIDs = data.map { $0.id }
        
        let request = MoveEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", moveIDs)
        
        let existingMoves = try context.fetch(request)
        let existingMoveDict = Dictionary(uniqueKeysWithValues: existingMoves.map { ($0.id, $0) })
        
        for moveData in data {
            let dto = MoveDTO(domain: moveData)
            if let existingEntity = existingMoveDict[moveData.id] {
                dto.update(existingEntity)
            } else {
                dto.toEntity(context: context)
            }
        }
        
        try coreData.saveContext()
    }
}
