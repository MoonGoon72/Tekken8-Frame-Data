//
//  CharacterRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import Foundation

protocol CharacterRepository {
    func fetchCharacters() async throws -> [Character]
    func characterImageURL(character: Character) throws -> URL
}
