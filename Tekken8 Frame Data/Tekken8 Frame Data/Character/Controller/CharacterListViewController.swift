//
//  CharacterListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/23/25.
//

import Combine
import SwiftUI
import UIKit

final class CharacterListViewController: UIViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    // TODO: supabaseManager 객체 관리 방향성 정하기
    private let supabaseManager = SupabaseManager()
    private let characterCollectionView: CharacterCollectionView
    private let characterViewModel = CharacterListViewModel()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDiffableDataSource()
        setupSearchController()
        setupDelegation()
    }
    
    override func loadView() {
        super.loadView()
        
        view = characterCollectionView
        fetchCharacters()
        bindViewModel()
    }
    
    private func setupDelegation() {
        characterCollectionView.setCollectionViewDelegate(self)
    }
    
    private func fetchCharacters() {
        Task {
            characterViewModel.fetchCharacters(using: supabaseManager)
        }
    }
    
    private func bindViewModel() {
        filteredCancellable = characterViewModel
            .$filteredCharacters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filteredCharacters in
                self?.updateSnapshot(for: filteredCharacters)
            }
    }
}

// MARK: - UISearchController method

private extension CharacterListViewController {
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
        characterViewModel.resetFilter()
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
        
        characterViewModel.filter(by: text)
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension CharacterListViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource( collectionView: characterCollectionView.characterCollectionView)
        { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CharacterCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                CharacterCell(character: itemIdentifier, viewModel: self.characterViewModel)
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
        print(characterViewModel.characters[indexPath.row])
        // 네비게이션
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
