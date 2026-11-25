//
//  DefaultMoveRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

protocol MoveRepository {
    @MainActor func fetchMoves(characterName name: String) async throws -> [Move]
}

final class DefaultMoveRepository: MoveRepository {
    private let manager: SupabaseManageable
    private let cache: FrameDataCache

    init(manager: SupabaseManageable, cache: FrameDataCache) {
        self.manager = manager
        self.cache = cache
    }

    @MainActor func fetchMoves(characterName name: String) async throws -> [Move] {
        let cachedMoves = try cache.fetchMoves(characterName: name)
        if !cachedMoves.isEmpty {
            return cachedMoves.map { $0.toDomain() }
        }

        let generation = cache.generation
        let moves = try await manager.fetchMoves(characterName: name)
        switch try cache.reconcileMoveResponse(moves.map(MoveDTO.init(domain:)), requestGeneration: generation) {
        case .current:
            return moves
        case .superseded:
            return try cache.fetchMoves(characterName: name).map { $0.toDomain() }
        }
    }
}
