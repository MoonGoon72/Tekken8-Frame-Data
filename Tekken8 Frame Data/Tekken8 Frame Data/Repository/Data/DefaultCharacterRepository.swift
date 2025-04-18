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
    
    init(manager: SupabaseManageable) {
        self.manager = manager
    }
    
    func fetchCharacters() async throws -> [Character] {
        try await manager.fetchCharacter()
    }
}
