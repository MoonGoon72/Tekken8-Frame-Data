//
//  DefaultMoveRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import CoreData
import Foundation

final class DefaultMoveRepository: MoveRepository {
    private let manager: SupabaseManageable
    private let coreData: CoreDataManageable
    
    init(manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.manager = manager
        self.coreData = coreData
    }
    
    func fetchMoves(characterName name: String) async throws -> [Move] {
        try await manager.fetchMoves(characterName: name)
    }
}
