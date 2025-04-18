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
    
    init(manager: SupabaseManageable) {
        self.manager = manager
    }
    
    func fetchMoves(characterName name: String) async throws -> [Move] {
        try await manager.fetchMoves(characterName: name)
    }
}
