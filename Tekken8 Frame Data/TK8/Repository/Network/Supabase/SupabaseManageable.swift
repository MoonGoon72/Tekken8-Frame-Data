//
//  SupabaseManageable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/11/25.
//

import Foundation

protocol SupabaseManageable {
    func fetchCharacter() async throws -> [Character]
    func fetchMoves(characterName name: String) async throws -> [Move]
    func fetchFrameDataVersion() async throws -> Int
    func fetchTekkenVersion() async throws -> String
    func imageURL(character: String) throws -> URL
}
