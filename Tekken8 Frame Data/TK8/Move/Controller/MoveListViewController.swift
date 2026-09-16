//
//  MoveListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Combine
import SwiftUI
import UIKit

final class MoveListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<MoveListSection, MoveListItem>
    private typealias MoveDataSource = UICollectionViewDiffableDataSource<MoveListSection, MoveListItem>
    
    private let moveListView: MoveListView
    private let moveListViewModel: MoveListViewModel
    private let container: DIContainer
    private let searchController: UISearchController
    private var filteredCancellable: AnyCancellable?
    private var dataSource: MoveDataSource?
    private var fetchStateCancellable: AnyCancellable?
    private let analytics: AnalyticsClient
    private let searchAnalyticsTracker: SearchAnalyticsTracker
    private let nativeAdLoader: NativeMoveAdLoader?
    private var hasLoadedInitialData = false
    private var isScreenVisible = false
    private var appliedMoveCount = 0
    
    private let character: Character
    
    init(
        character: Character,
        moveListViewModel viewModel: MoveListViewModel,
        container: DIContainer,
        analytics: AnalyticsClient,
        nativeAdService: (any BannerAdServing)? = nil
    ) {
        moveListView = MoveListView()
        moveListViewModel = viewModel
        self.container = container
        searchController = UISearchController(searchResultsController: nil)
        self.character = character
        self.analytics = analytics
        if let nativeAdService, nativeAdService.configuration.usesNativeMoveAds {
            nativeAdLoader = NativeMoveAdLoader(service: nativeAdService, analytics: analytics)
        } else {
            nativeAdLoader = nil
        }
        searchAnalyticsTracker = SearchAnalyticsTracker(
            scope: .moveList,
            analytics: analytics,
            characterID: character.nameEN.lowercased()
        )
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        view = moveListView
        fetchMoves()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.log(.screenViewed(.moveList))
        isScreenVisible = true
        logInitialDisplayIfNeeded()
        nativeAdLoader?.load(placements: Self.nativeAdPlacements(moveCount: moveListViewModel.filtered.count), from: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isScreenVisible = false
        searchAnalyticsTracker.cancel()
    }
    
    override func setupDelegation() {
        super.setupDelegation()
        
        moveListView.setCollectionViewDelegate(self)
        searchController.delegate = self
    }
    
    override func setupDataSource() {
        super.setupDataSource()
        
        setupDiffableDataSource()
    }
    
    override func setupNavigationBar() {
        super.setupNavigationBar()
        
        setupSearchController()
        navigationItem.title = Bundle.main.preferredLocalizations.first == "ko" ? character.nameKR : character.nameEN
        navigationController?.navigationBar.tintColor = .tkRed
        navigationController?.navigationBar.topItem?.title = ""
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease"), style: .plain, target: self, action: #selector(filterButtonTapped))
        navigationItem.rightBarButtonItems = [settingsButton, filterButton]
    }

    @objc private func settingsButtonTapped() {
        let settingsViewController = container.makeSettingViewController()
        navigationController?.pushViewController(settingsViewController, animated: true)
    }

    @objc private func filterButtonTapped() {
        analytics.log(.filterOpened(characterID: character.nameEN.lowercased()))
        let filterView = FilterView(
            moveListViewModel: moveListViewModel,
            characterID: character.nameEN.lowercased(),
            analytics: analytics
        )
        let filterViewController = UIHostingController(rootView: filterView)
        navigationController?.modalPresentationStyle = .popover
        navigationController?.pushViewController(filterViewController, animated: true)
    }

    override func bindViewModel() {
        super.bindViewModel()
        
        filteredCancellable = moveListViewModel
            .$filtered
            .sink { [weak self] filteredMoves in
                self?.applySnapshot(for: filteredMoves)
            }

        nativeAdLoader?.onAdsChanged = { [weak self] in
            guard let self else { return }
            self.applySnapshot(for: self.moveListViewModel.filtered)
        }

        fetchStateCancellable = moveListViewModel
            .$fetchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard state == .failed else { return }
                guard let self else { return }
                self.analytics.log(.moveListLoadFailed(
                    characterID: self.character.nameEN.lowercased(),
                    failureCode: .repositoryError
                ))
            }
    }
    
    private func fetchMoves() {
        Task {
            moveListViewModel.setLanguage(code: Bundle.main.preferredLocalizations.first)
            moveListViewModel.fetchMoves(characterName: character.nameEN)
        }
    }
}

// MARK: - UISearchController, UISearchREsultsUpdating method

extension MoveListViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    func willDismissSearchController(_ searchController: UISearchController) {
        searchAnalyticsTracker.cancel()
        moveListViewModel.resetFilter()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard moveListViewModel.fetchState == .loaded else {
            searchAnalyticsTracker.cancel()
            moveListViewModel.updateKeyword(by: text)
            return
        }

        searchAnalyticsTracker.textDidChange(to: text)
        moveListViewModel.updateKeyword(by: text)
    }
}

// MARK: UISearchBar conformance

extension MoveListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UISearchController method

private extension MoveListViewController {
    func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = Texts.placeholder.localized()
        searchController.automaticallyShowsCancelButton = true
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension MoveListViewController {
    func setupDiffableDataSource() {
        // Cell 등록
        dataSource = MoveDataSource(collectionView: moveListView.moveCollectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case .move(let move):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MoveCell.reuseIdentifier, for: indexPath)
                cell.contentConfiguration = UIHostingConfiguration {
                    MoveCell(move: move)
                }
                return cell
            case .nativeAd(let placement):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NativeMoveAdCardCell.reuseIdentifier, for: indexPath) as! NativeMoveAdCardCell
                if let ad = self.nativeAdLoader?.nativeAd(for: placement) {
                    cell.configure(with: ad)
                }
                return cell
            }
        }
        // 헤더용 SupplementaryRegisteration 정의
        let headerRegisteration = UICollectionView.SupplementaryRegistration<MoveSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader) { headerView, elementKind, indexPath in
                guard case .moves(let sectionTitle)? = self.dataSource?.snapshot().sectionIdentifiers[indexPath.section] else { return }
                headerView.titleLabel.text = sectionTitle
            }
        // CollectionView에 SupplimentaryRegistration 등록
        moveListView.moveCollectionView.register(
            MoveSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: MoveSectionHeaderView.reuseIdentifier
        )
        moveListView.moveCollectionView.register(NativeMoveAdCardCell.self, forCellWithReuseIdentifier: NativeMoveAdCardCell.reuseIdentifier)
        // DiffableDataSource에 provider로 연결
        dataSource?.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegisteration,
                for: indexPath
            )
        }
    }
    
    func applySnapshot(for moves: [LocalizedMove]) {
        var snapshot = Snapshot()
        let orderSections = orderedSections(from: moves)
        let availableNativeAdPlacements = Set(Self.nativeAdPlacements(moveCount: moves.count).filter {
            nativeAdLoader?.nativeAd(for: $0) != nil
        })
        var displayedMoveCount = 0

        for section in orderSections {
            let items = moves
                .filter { $0.section == section }
                .sorted { $0.id < $1.id }
                .map(MoveListItem.move)

            let sectionEndCount = displayedMoveCount + items.count
            let placements = availableNativeAdPlacements.filter {
                displayedMoveCount < $0 && $0 <= sectionEndCount
            }.sorted()
            if placements.isEmpty {
                snapshot.appendSections([.moves(section)])
                snapshot.appendItems(items, toSection: .moves(section))
            } else {
                snapshot.appendSections([.moves(section)])
                var itemOffset = 0
                var destinationSection = MoveListSection.moves(section)
                for placement in placements {
                    let itemCount = placement - displayedMoveCount - itemOffset
                    snapshot.appendItems(Array(items[itemOffset..<(itemOffset + itemCount)]), toSection: destinationSection)
                    snapshot.appendSections([.nativeAd(placement)])
                    snapshot.appendItems([.nativeAd(placement)], toSection: .nativeAd(placement))
                    itemOffset += itemCount
                    if itemOffset < items.count {
                        destinationSection = .continuation(section, placement)
                        snapshot.appendSections([destinationSection])
                    }
                }
                if itemOffset < items.count {
                    snapshot.appendItems(Array(items.dropFirst(itemOffset)), toSection: destinationSection)
                }
            }
            displayedMoveCount += items.count
        }
        let headerlessIndexes = Set(snapshot.sectionIdentifiers.enumerated().compactMap { index, section in
            switch section {
            case .nativeAd, .continuation: index
            case .moves: nil
            }
        })
        moveListView.setHeaderlessSectionIndexes(headerlessIndexes)
        let attemptID = searchAnalyticsTracker.attemptID
        dataSource?.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.appliedMoveCount = moves.count
            self.searchAnalyticsTracker.resultsApplied(count: moves.count, for: attemptID)
            self.logInitialDisplayIfNeeded()
        }
        nativeAdLoader?.load(placements: Self.nativeAdPlacements(moveCount: moves.count), from: self)
    }

    func logInitialDisplayIfNeeded() {
        if isScreenVisible, appliedMoveCount > 0, !hasLoadedInitialData {
            hasLoadedInitialData = true
            analytics.log(.moveListDisplayed(
                characterID: character.nameEN.lowercased(),
                moveCount: appliedMoveCount
            ))
        }
    }
    
    // 첫 등장 순서를 유지하면서 정렬
    func orderedSections(from items: [LocalizedMove]) -> [String] {
        // 현재 스냅샷에 실제로 등장한 섹션들
        let allSections = items.compactMap { $0.section }
        let present = Set(allSections)

        // 앞에 고정으로 뿌릴 섹션(양언어 지원)
        let commonOrder = [
            "히트","레이지","일반","앉은 상태",
            "Heat","Rage","General","While crouching"
        ]
        let frontSections = commonOrder.filter { present.contains($0) }

        // 뒤에 보낼 섹션(양언어 지원)
        let endOrder = [
            "잡기","반격기",
            "Throw","Reversal"
        ]
        let tailSections = endOrder.filter { present.contains($0) }

        // 중간: 캐릭 고유 섹션 = 전체 - (앞+뒤)
        let middleSet = present
            .subtracting(frontSections)
            .subtracting(tailSections)

        // 중간 섹션 정렬: "해당 섹션이 처음 나타난 아이템의 id" 오름차순
        let sortedMiddle = middleSet.sorted { a, b in
            let minA = items.filter { $0.section == a }.map(\.id).min() ?? .max
            let minB = items.filter { $0.section == b }.map(\.id).min() ?? .max
            return minA < minB
        }

        // 최종 순서
        return frontSections + sortedMiddle + tailSections
    }
}

extension MoveListViewController {
    static func nativeAdPlacements(moveCount: Int) -> [Int] {
        guard moveCount >= 4 else { return [] }
        return Array(stride(from: 4, through: moveCount, by: 20))
    }
}

// MARK: - UICollectionViewDelegate Conformance
// TODO: 추후 특정 기술에 대한 액션을 추가한다면 필요할지도?
extension MoveListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
}

private extension MoveListViewController {
    enum Texts {
        static let placeholder = "Search"
    }

    enum MoveListSection: Hashable {
        case moves(String)
        case nativeAd(Int)
        case continuation(String, Int)
    }

    enum MoveListItem: Hashable {
        case move(LocalizedMove)
        case nativeAd(Int)
    }
}
