//
//  DefaultCharacterRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import Foundation

protocol CharacterRepository {
    @MainActor func fetchCharacters() async throws -> [Character]
    func characterImageURL(character: Character) throws -> URL
}

final class DefaultCharacterRepository: CharacterRepository {
    private let manager: SupabaseManageable
    private let cache: FrameDataCache
    
    init(manager: SupabaseManageable, cache: FrameDataCache) {
        self.manager = manager
        self.cache = cache
    }
    
    @MainActor func fetchCharacters() async throws -> [Character] {
        if let characters = try? cache.fetchCharacters(), !characters.isEmpty {
            return characters.map { $0.toDomain() }
        }

        let generation = cache.generation
        let characters = try await manager.fetchCharacter()
        switch try cache.reconcileCharacterResponse(
            characters.map(CharacterDTO.init(domain:)),
            requestGeneration: generation
        ) {
        case .current:
            return characters
        case .superseded:
            return try cache.fetchCharacters().map { $0.toDomain() }
        }
    }

    func characterImageURL(character: Character) throws -> URL {
        guard let url = URL(string: character.imageURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw URLError(.badURL)
        }

        return url
    }
}
