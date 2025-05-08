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
    private typealias Snapshot = NSDiffableDataSourceSnapshot<String, Move>
    private typealias MoveDataSource = UICollectionViewDiffableDataSource<String, Move>
    
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
        navigationItem.title = character.nameKR
        navigationController?.navigationBar.tintColor = .tkRed
        navigationController?.navigationBar.topItem?.title = ""
        navigationItem.rightBarButtonItem = ReportButtonFactory.make(
            target: ReportButtonFactory.self,
            action: #selector(ReportButtonFactory.sendBugReport)
        )
    }
    
    override func bindViewModel() {
        super.bindViewModel()
        
        filteredCancellable = moveListViewModel
            .$filteredMoves
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filteredMoves in
                self?.updateSnapshot(for: filteredMoves)
            }
    }
    
    private func fetchMoves() {
        Task {
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
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        
        // 필터링 로직
        moveListViewModel.filter(by: text)
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
        searchController.searchBar.placeholder = Texts.placeholder
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
    
    func updateSnapshot(for moves: [Move]) {
        guard !moves.isEmpty else {
            dataSource?.apply(Snapshot(), animatingDifferences: false)
            return
        }
        var snapshot = Snapshot()
        let sections = Set(moves.map { $0.section })
        
        // 앞에 보여줄 섹션
        let commonOrder = ["히트", "레이지", "일반", "앉은 상태"]
        let frontSections = commonOrder.filter { sections.contains($0) }
        
        // 뒤에 보여줄 섹션
        let endOrder = ["잡기", "반격기"]
        let tailSections = endOrder.filter { sections.contains($0) }
        
        // 중간에 보여줄, 캐릭터 별 고유 섹션
        let middleSections = sections
            .subtracting(frontSections)
            .subtracting(tailSections)
        let sortedMiddle = middleSections.sorted { a, b in
            let minA = moves.filter { $0.section == a }.map(\.id).min() ?? 0
            let minB = moves.filter { $0.section == b }.map(\.id).min() ?? 0
            return minA < minB
        }
        
        // 최종 순서대로 합치기
        let orderSections = frontSections + sortedMiddle + tailSections
        snapshot.appendSections(orderSections)
        
        for section in orderSections {
            let items = moves
                .filter { $0.section == section }
                .sorted { $0.id < $1.id }
            snapshot.appendItems(items, toSection: section)
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
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
