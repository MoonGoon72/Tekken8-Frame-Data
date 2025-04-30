//
//  CharacterRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

protocol CharacterRepository {
    func fetchCharacters() async throws -> [Character]
}
