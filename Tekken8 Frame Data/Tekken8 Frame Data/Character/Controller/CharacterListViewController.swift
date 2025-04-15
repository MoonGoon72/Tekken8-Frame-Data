//
//  CharacterListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/23/25.
//

import Combine
import SwiftUI
import UIKit

final class CharacterListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    // TODO: supabaseManager 객체 관리 방향성 정하기
    private let supabaseManager = SupabaseManager()
    private let characterCollectionView: CharacterCollectionView
    private let characterListViewModel = CharacterListViewModel()
    private var filteredCancellable: AnyCancellable?
    private var dataSource: CharacterDataSource?
    
    init() {
        characterCollectionView = CharacterCollectionView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        characterCollectionView = CharacterCollectionView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        super.loadView()
        
        view = characterCollectionView
        fetchCharacters()
    }
    
    override func setupDelegation() {
        super.setupDelegation()
        
        characterCollectionView.setCollectionViewDelegate(self)
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
        
        filteredCancellable = characterListViewModel
            .$filteredCharacters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filteredCharacters in
                self?.updateSnapshot(for: filteredCharacters)
            }
    }
    
    private func fetchCharacters() {
        Task {
            characterListViewModel.fetchCharacters(using: supabaseManager)
        }
    }
}

// MARK: - UISearchController method

private extension CharacterListViewController {
    // FIXME: setup은 굳이 extension으로 뺴줄 필요가 있을까? delegate는 delegate용 함수에 넣어주자.
    func setupSearchController() {
        let searchController = UISearchController(searchResultsController: nil)
        
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = Texts.placeholder
        navigationItem.searchController = searchController
    }
}

// MARK: UISearchController conformance

extension CharacterListViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        characterListViewModel.resetFilter()
    }
}

// MARK: UISearchBar conformance

extension CharacterListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: UISearchResultsUpdating conformance

extension CharacterListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        characterListViewModel.filter(by: text)
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension CharacterListViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource( collectionView: characterCollectionView.characterCollectionView)
        { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CharacterCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                CharacterCell(character: itemIdentifier, viewModel: self.characterListViewModel)
            }
            cell.layer.borderWidth = 0.5
            cell.layer.cornerRadius = 5
            return cell
        }
    }
    
    func updateSnapshot(for characters: [Character]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(characters)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate Conformance

extension CharacterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let character = characterListViewModel.characters[indexPath.row]
        let moveListViewController = MoveListViewController(character: character)
        navigationController?.pushViewController(moveListViewController, animated: true)
    }
}

private enum Section {
    case main
}

private extension CharacterListViewController {
    enum Texts {
        static let placeholder = "캐릭터 이름을 입력해주세요."
    }
}
