//
//  MoveCollectionViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Foundation

@MainActor
final class MoveCollectionViewModel {
    @Published private(set) var filteredMoves: [Move] = []
    private(set) var moves: [Move] = []
    
    func fetchMoves(using manager: SupabaseManageable, characterName name: String) {
        Task {
            do {
                let fetchedMoves: [Move] = try await manager.fetchMoves(characterName: name)
                filteredMoves = fetchedMoves
                print(fetchedMoves)
            } catch {
                NSLog("❌ Error fetching \(name)'s moves: \(error)")
            }
        }
    }
}
