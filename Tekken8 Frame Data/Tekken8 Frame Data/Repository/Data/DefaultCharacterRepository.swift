//
//  DefaultCharacterRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import CoreData
import Foundation

final class DefaultCharacterRepository: CharacterRepository {
    private let manager: SupabaseManageable
    private let coreData: CoreDataManageable
    
    init(manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.manager = manager
        self.coreData = coreData
    }
    
    func fetchCharacters() async throws -> [Character] {
        try await manager.fetchCharacter().sorted { $0.name < $1.name }
    }
}
