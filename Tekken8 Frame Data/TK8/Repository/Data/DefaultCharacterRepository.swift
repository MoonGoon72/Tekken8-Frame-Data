//
//  DefaultCharacterRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import CoreData

final class DefaultCharacterRepository: CharacterRepository {
    private let manager: SupabaseManageable
    private let coreData: CoreDataManageable
    
    init(manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.manager = manager
        self.coreData = coreData
    }
    
    func fetchCharacters() async throws -> [Character] {
        let request = CharacterEntity.fetchRequest()
        
        if let result = try? coreData.fetch(request), !result.isEmpty {
            return result.map({ CharacterDTO(entity: $0).toDomain() })
        }
        
        let fetchedCharacters = try await manager.fetchCharacter()
        try addToCoreData(fetchedCharacters)
        
        return fetchedCharacters
    }
    
    private func addToCoreData(_ data: [Character]) throws {
        let context = coreData.context
        let characterIDs = data.map { $0.id }
        
        let request = CharacterEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", characterIDs)
        
        let existingCharacters = try context.fetch(request)
        let existingCharacterDict = Dictionary(uniqueKeysWithValues: existingCharacters.map { ($0.id, $0) })
        
        for characterData in data {
            let dto = CharacterDTO(domain: characterData)
            if let existingEntity = existingCharacterDict[characterData.id] {
                dto.update(existingEntity)
            } else {
                dto.toEntity(in: context)
            }
        }
        
        try coreData.saveContext()
    }
}
