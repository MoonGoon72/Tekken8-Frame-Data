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
        data.forEach { move in
            let dto = MoveDTO(domain: move)
            dto.toEntity(context: coreData.context)
        }
        try coreData.saveContext()
    }
}
