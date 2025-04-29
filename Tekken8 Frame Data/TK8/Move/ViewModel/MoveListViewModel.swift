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
                moves = fetchedMoves
            } catch {
                NSLog("❌ Error fetching \(name)'s moves: \(error)")
            }
        }
    }
    
    func filter(by keyword: String) {
        let keyword = keyword.lowercased()
        if keyword.isEmpty {
            filteredMoves = moves
        } else {
            filteredMoves = moves.filter { move in
                let enMatch = move.skillNameEN.lowercased().contains(keyword)
                let krMatch = move.skillNameKR?.lowercased().contains(keyword) ?? false
                let nickMatch = move.skillNickname?.lowercased().contains(keyword) ?? false
                let commandMatch = move.command?.lowercased().contains(keyword) ?? false
                
                return enMatch || krMatch || nickMatch || commandMatch
            }
        }
    }
    
    func resetFilter() {
        filteredMoves = moves
    }
}
