//
//  DIContainer.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/18/25.
//

import UIKit

final class DIContainer {
    private let coreDataManager: CoreDataManageable
    private let supabaseManager: SupabaseManageable
    private let userDefaultsManager: UserDefaultsManageable
    private let preference: CharacterLayoutPreference
    private let analytics: AnalyticsClient
    @MainActor private lazy var purchases = AdRemovalPurchaseService(store: StoreKitAdRemovalStore())
    @MainActor private lazy var ads = BannerAdService(purchases: purchases)

    @MainActor private func withBottomAd<T: BaseViewController>(_ controller: T, placement: BannerPlacement) -> T {
        controller.bannerAdHost = makeBottomAdHost(placement: placement)
        return controller
    }

    @MainActor private func makeBottomAdHost(placement: BannerPlacement, contentSpacing: CGFloat = 0) -> any ScreenAdHosting {
        // Keep the dedicated Unity banner validation scheme on its original format.
        if ads.configuration.isDebug && ads.configuration.mediationTestRequested {
            return BannerAdHost(service: ads, placement: placement, analytics: analytics, contentSpacing: contentSpacing)
        }
        return NativeAdHost(service: ads, placement: placement, analytics: analytics, contentSpacing: contentSpacing)
    }

    @MainActor func makeSettingViewController() -> SettingViewController {
        withBottomAd(SettingViewController(analytics: analytics, ads: ads, purchaseViewModel: SettingsPurchaseViewModel(purchases: purchases)), placement: .settings)
    }

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
        return withBottomAd(CharacterListViewController(
            characterListViewModel: viewModel,
            container: self,
            preference: preference,
            analytics: analytics
        ), placement: .characterList)
    }
    
    @MainActor func makeMoveListViewController(character: Character) -> MoveListViewController {
        let repository = DefaultMoveRepository(manager: supabaseManager, coreData: coreDataManager)
        let moveVideoRepository = DefaultMoveVideoRepository(
            dataSource: supabaseManager,
            urlBuilder: ConfiguredMoveVideoURLBuilder()
        )
        let viewModel = MoveListViewModel(moveRepository: repository, moveVideoRepository: moveVideoRepository)
        let controller = MoveListViewController(
            character: character,
            moveListViewModel: viewModel,
            container: self,
            analytics: analytics,
            moveVideoPlaybackURLProvider: DefaultMoveVideoPlaybackURLProvider(dataSource: supabaseManager),
            nativeAdService: ads
        )
        // A configured native unit replaces the move-list banner. Debug uses the
        // Google sample unit; Release becomes eligible only with valid real IDs.
        return ads.configuration.usesNativeMoveAds ? controller : withBottomAd(controller, placement: .moveList)
    }

    @MainActor func makeMoveVideoPlayerViewController(
        move: LocalizedMove, reference: MoveVideoReference, playbackURLProvider: MoveVideoPlaybackURLProviding
    ) -> MoveVideoPlayerViewController {
        let controller = MoveVideoPlayerViewController(move: move, reference: reference, playbackURLProvider: playbackURLProvider)
        controller.bannerAdHost = makeBottomAdHost(placement: .moveVideoDetail, contentSpacing: 12)
        return controller
    }

    @MainActor func makeMemoListViewController(characterListViewModel: any CharacterSelectable) -> MemoListViewController {
        let repository = DefaultMemoRepository(coreDataManager: coreDataManager)
        let viewModel = MemoViewModel(memoRepository: repository)

        return withBottomAd(MemoListViewController(
            viewModel: viewModel,
            characterListViewModel: characterListViewModel,
            analytics: analytics
        ) { memo in
                self.makeMemoComposeViewController(
                    memoViewModel: viewModel,
                    characterListViewModel: characterListViewModel,
                    memo: memo
                )
            }, placement: .memoList)
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
