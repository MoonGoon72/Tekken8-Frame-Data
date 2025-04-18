//
//  MoveListViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Foundation

@MainActor
final class MoveListViewModel {
    @Published private(set) var filteredMoves: [Move] = []
    private(set) var moves: [Move] = []
    private let repository: MoveRepository
    
    init(moveRepository repository: MoveRepository) {
        self.repository = repository
    }
    
    func fetchMoves(characterName name: String) {
        Task {
            do {
                let fetchedMoves: [Move] = try await repository.fetchMoves(characterName: name)
                filteredMoves = fetchedMoves
                print(fetchedMoves)
            } catch {
                NSLog("❌ Error fetching \(name)'s moves: \(error)")
            }
        }
    }
}
