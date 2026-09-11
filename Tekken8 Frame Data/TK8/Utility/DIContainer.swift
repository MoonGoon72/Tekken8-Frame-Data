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
    private let userDefaultsManager: UserDefaultsManageable
    private let preference: CharacterLayoutPreference
    private let analytics: AnalyticsClient

    init(analytics: AnalyticsClient? = nil) {
        coreDataManager = CoreDataManager()
        supabaseManager = SupabaseManager()
        userDefaultsManager = UserDefaultsManager()
        preference = CharacterLayoutPreference(manager: userDefaultsManager)
        self.analytics = analytics ?? (TK8AnalyticsCollectionPolicy.isEnabled
            ? FirebaseAnalyticsClient() : NoOpAnalyticsClient())
    }
    
    @MainActor func makeCharacterListViewController() -> CharacterListViewController {
        let repository = DefaultCharacterRepository(manager: supabaseManager, coreData: coreDataManager)
        let viewModel = CharacterListViewModel(characterRepository: repository)
        return CharacterListViewController(
            characterListViewModel: viewModel,
            container: self,
            preference: preference,
            analytics: analytics
        )
    }
    
    @MainActor func makeMoveListViewController(character: Character) -> MoveListViewController {
        let repository = DefaultMoveRepository(manager: supabaseManager, coreData: coreDataManager)
        let viewModel = MoveListViewModel(moveRepository: repository)
        return MoveListViewController(
            character: character,
            moveListViewModel: viewModel,
            container: self,
            analytics: analytics
        )
    }

    @MainActor func makeMemoListViewController(characterListViewModel: any CharacterSelectable) -> MemoListViewController {
        let repository = DefaultMemoRepository(coreDataManager: coreDataManager)
        let viewModel = MemoViewModel(memoRepository: repository)

        return MemoListViewController(
            viewModel: viewModel,
            characterListViewModel: characterListViewModel,
            analytics: analytics
        ) { memo in
                self.makeMemoComposeViewController(
                    memoViewModel: viewModel,
                    characterListViewModel: characterListViewModel,
                    memo: memo
                )
            }
    }

    @MainActor func makeMemoComposeViewController(
        memoViewModel: MemoViewModel,
        characterListViewModel: any CharacterSelectable,
        memo: Memo?
    ) -> MemoComposeViewController {
        MemoComposeViewController(
            memoViewModel: memoViewModel,
            characterListViewModel: characterListViewModel,
            memo: memo,
            analytics: analytics,
            makeCharacterSelectViewController: { self.makeCharacterSelectViewController(viewModel: characterListViewModel)
            }
        )
    }

    @MainActor private func makeCharacterSelectViewController(viewModel: any CharacterSelectable) -> CharacterSelectViewController {
        return CharacterSelectViewController(viewModel: viewModel, layoutMode: preference.fetchLayoutMode(), analytics: analytics)
    }

    @MainActor func makeVersionManager() -> VersionManager {
        VersionManager(manager: supabaseManager, coreData: coreDataManager)
    }
}
