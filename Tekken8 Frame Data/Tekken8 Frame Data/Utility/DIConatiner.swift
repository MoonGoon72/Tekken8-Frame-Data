//
//  DIConatiner.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/18/25.
//

import Foundation

final class DIConatiner {
    private let manager: SupabaseManageable = SupabaseManager()
    
    @MainActor func makeCharacterListViewController() -> CharacterListViewController {
        let repository = DefaultCharacterRepository(manager: manager)
        let viewModel = CharacterListViewModel(characterRepository: repository)
        return CharacterListViewController(characterListViewModel: viewModel, container: self)
    }
    
    @MainActor func makeMoveListViewController(character: Character) -> MoveListViewController {
        let repository = DefaultMoveRepository(manager: manager)
        let viewModel = MoveListViewModel(moveRepository: repository)
        return MoveListViewController(character: character, moveListViewModel: viewModel, container: self)
    }
}
