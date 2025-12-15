//
//  MoveListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Combine
import FirebaseAnalytics
import SwiftUI
import UIKit

final class MoveListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<String, LocalizedMove>
    private typealias MoveDataSource = UICollectionViewDiffableDataSource<String, LocalizedMove>
    
    private let moveListView: MoveListView
    private let moveListViewModel: MoveListViewModel
    private let container: DIContainer
    private let searchController: UISearchController
    private var filteredCancellable: AnyCancellable?
    private var dataSource: MoveDataSource?
    
    private let character: Character
    
    init(character: Character, moveListViewModel viewModel: MoveListViewModel, container: DIContainer) {
        moveListView = MoveListView()
        moveListViewModel = viewModel
        self.container = container
        searchController = UISearchController(searchResultsController: nil)
        self.character = character
        
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
        navigationItem.rightBarButtonItem = settingsButton
    }

    @objc private func settingsButtonTapped() {
        let settingsViewController = SettingViewController()
        navigationController?.pushViewController(settingsViewController, animated: true)
    }
    
    override func bindViewModel() {
        super.bindViewModel()
        
        filteredCancellable = moveListViewModel
            .$filtered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filteredMoves in
                self?.applySnapshot(for: filteredMoves)
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
        moveListViewModel.resetFilter()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // 필터링 로직
        moveListViewModel.filter(by: text)
        Analytics.logEvent("search_move", parameters: [
            "character_name": character.nameEN,
            "keyword": text
        ])
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MoveCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                MoveCell(move: itemIdentifier)
            }
            return cell
        }
        // 헤더용 SupplementaryRegisteration 정의
        let headerRegisteration = UICollectionView.SupplementaryRegistration<MoveSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader) { headerView, elementKind, indexPath in
                let sectionTitle = self.dataSource?.snapshot().sectionIdentifiers[indexPath.section] ?? ""
                headerView.titleLabel.text = sectionTitle
            }
        // CollectionView에 SupplimentaryRegistration 등록
        moveListView.moveCollectionView.register(
            MoveSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: MoveSectionHeaderView.reuseIdentifier
        )
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
        guard !moves.isEmpty else {
            dataSource?.apply(snapshot, animatingDifferences: false)
            return
        }
        
        let orderSections = orderedSections(from: moves)
        snapshot.appendSections(orderSections)
        
        for section in orderSections {
            let items = moves
                .filter { $0.section == section }
                .sorted { $0.id < $1.id }
            snapshot.appendItems(items, toSection: section)
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
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
        // (네가 기존에 쓰던 기준과 동일)
        let sortedMiddle = middleSet.sorted { a, b in
            let minA = items.filter { $0.section == a }.map(\.id).min() ?? .max
            let minB = items.filter { $0.section == b }.map(\.id).min() ?? .max
            return minA < minB
        }

        // 최종 순서
        return frontSections + sortedMiddle + tailSections
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
        static let placeholder = "기술명을 입력해주세요."
    }
}
