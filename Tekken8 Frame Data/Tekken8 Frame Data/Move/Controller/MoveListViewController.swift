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
    
    private let supabaseManager = SupabaseManager()
    private let moveListView: MoveListView
    private let moveListViewModel: MoveListViewModel
    private let searchController: UISearchController
    private var filteredCancellable: AnyCancellable?
    private var dataSource: MoveDataSource?
    
    private let character: Character
    
    init(character: Character) {
        moveListView = MoveListView()
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
            moveListViewModel.fetchMoves(characterName: character.name)
        }
    }
}

// MARK: - UISearchController, UISearchREsultsUpdating method

extension MoveListViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    func willDismissSearchController(_ searchController: UISearchController) {
        // 나가면 초기화하는 로직
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        // 필터링 로직
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
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = Texts.placeholder
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension MoveListViewController {
    func setupDiffableDataSource() {
        dataSource = MoveDataSource(collectionView: moveListView.moveCollectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MoveCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                MoveCell(move: itemIdentifier)
            }
            cell.layer.borderWidth = 0.5
            cell.layer.cornerRadius = 5
            return cell
        }
    }
    
    func updateSnapshot(for moves: [Move]) {
        var snapshot = Snapshot()
        let section = moves.map { $0.section }
        snapshot.appendSections(section.count > 0 ? Array(Set(section))  : ["default"])
        snapshot.appendItems(moves)
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
