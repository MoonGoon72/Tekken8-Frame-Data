//
//  DefaultMoveRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import CoreData

protocol MoveRepository {
    @MainActor func fetchMoves(characterName name: String) async throws -> [Move]
}

final class DefaultMoveRepository: MoveRepository {
    private let manager: SupabaseManageable
    private let coreData: CoreDataManageable
    
    init(manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.manager = manager
        self.coreData = coreData
    }
    
    @MainActor func fetchMoves(characterName name: String) async throws -> [Move] {
        let request = MoveEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        request.predicate = NSPredicate(format: "characterName == %@", name)
        
        let result = try coreData.fetch(request)
        if !result.isEmpty {
            return result.map({ MoveDTO(entity: $0).toDomain() })
        }
        
        let generation = coreData.frameDataGeneration
        let fetchedMoves = try await manager.fetchMoves(characterName: name)
        guard generation == coreData.frameDataGeneration else {
            return try coreData.fetch(request).map { MoveDTO(entity: $0).toDomain() }
        }
        try Task.checkCancellation()
        if !coreData.isReplacingFrameData {
            try addToCoreData(fetchedMoves)
        }
        
        return fetchedMoves
    }

    @MainActor
    private func addToCoreData(_ data: [Move]) throws {
        let context = coreData.context
        let moveIDs = data.map { $0.id }
        
        let request = MoveEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", moveIDs)
        
        let existingMoves = try context.fetch(request)
        let existingMoveDict = Dictionary(uniqueKeysWithValues: existingMoves.map { ($0.id, $0) })
        
        let originalValues = existingMoves.map { entity in
            let keys = Array(entity.entity.attributesByName.keys)
            return (entity, entity.dictionaryWithValues(forKeys: keys))
        }
        var inserted: [MoveEntity] = []
        for moveData in data {
            let dto = MoveDTO(domain: moveData)
            if let existingEntity = existingMoveDict[moveData.id] {
                dto.update(existingEntity)
            } else {
                inserted.append(dto.toEntity(context: context))
            }
        }
        
        do {
            try coreData.saveContext()
        } catch {
            inserted.forEach(coreData.delete)
            for (entity, original) in originalValues {
                entity.setValuesForKeys(original)
            }
            throw error
        }
    }
}
