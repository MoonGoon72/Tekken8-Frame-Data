//
//  DIContainer.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/18/25.
//

import Foundation

final class DIContainer {
    private let coreDataManager: CoreDataManageable
    private let supabaseManager: SupabaseManageable
    
    init() {
        coreDataManager = CoreDataManager()
        supabaseManager = SupabaseManager()
    }
    
    @MainActor func makeCharacterListViewController() -> CharacterListViewController {
        let repository = DefaultCharacterRepository(manager: supabaseManager, coreData: coreDataManager)
        let viewModel = CharacterListViewModel(characterRepository: repository)
        return CharacterListViewController(characterListViewModel: viewModel, container: self)
    }
    
    @MainActor func makeMoveListViewController(character: Character) -> MoveListViewController {
        let repository = DefaultMoveRepository(manager: supabaseManager, coreData: coreDataManager)
        let viewModel = MoveListViewModel(moveRepository: repository)
        return MoveListViewController(character: character, moveListViewModel: viewModel, container: self)
    }
    
    @MainActor func makeVersionManager() -> VersionManager {
        VersionManager(manager: supabaseManager, coreData: coreDataManager)
    }
}
