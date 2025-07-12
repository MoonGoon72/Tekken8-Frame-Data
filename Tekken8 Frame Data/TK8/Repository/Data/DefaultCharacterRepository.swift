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
        data.forEach { item in
            let dto = CharacterDTO(domain: item)
            dto.toEntity(in: coreData.context)
        }
        try coreData.saveContext()
    }
}
