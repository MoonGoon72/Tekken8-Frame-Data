//
//  MoveRepository.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/16/25.
//

import Foundation

protocol MoveRepository {
    func fetchMoves(characterName name: String) async throws -> [Move]
}
