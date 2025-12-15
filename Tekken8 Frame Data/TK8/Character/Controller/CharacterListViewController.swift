//
//  CharacterListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/23/25.
//

import Combine
import FirebaseAnalytics
import SwiftUI
import UIKit

final class CharacterListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>

    private let characterCollectionView: CharacterCollectionView
    private let characterListViewModel: CharacterListViewModel
    private let container: DIContainer
    private let searchController: UISearchController
    private var filteredCancellable: AnyCancellable?
    private var dataSource: CharacterDataSource?
    
    init(characterListViewModel viewModel: CharacterListViewModel, container: DIContainer) {
        characterCollectionView = CharacterCollectionView()
        characterListViewModel = viewModel
        self.container = container
        searchController = UISearchController(searchResultsController: nil)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }
        
    override func loadView() {
        super.loadView()
        
        view = characterCollectionView
        fetchCharacters()
    }
    
    override func setupDelegation() {
        super.setupDelegation()
        
        characterCollectionView.setCollectionViewDelegate(self)
        searchController.delegate = self
    }
    
    override func setupDataSource() {
        super.setupDataSource()
        
        setupDiffableDataSource()
    }
    
    override func setupNavigationBar() {
        super.setupNavigationBar()
        
        setupSearchController()
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .tkRed
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    @objc private func settingsButtonTapped() {
        let settingsViewController = SettingViewController()
        navigationController?.pushViewController(settingsViewController, animated: true)
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
            characterListViewModel.fetchCharacters()
        }
    }
}

// MARK: - UISearchController method

private extension CharacterListViewController {
    func setupSearchController() {
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsCancelButton = true
        searchController.searchBar.placeholder = Texts.placeholder.localized()
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
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        
        characterListViewModel.filter(by: text)
        Analytics.logEvent("search_character", parameters: ["keyword": text])
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension CharacterListViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource(collectionView: characterCollectionView.characterCollectionView)
        { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CharacterCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                CharacterCell(character: itemIdentifier, viewModel: self.characterListViewModel)
            }
            return cell
        }
    }
    
    func updateSnapshot(for characters: [Character]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(characters, toSection: .main)
        
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate Conformance

extension CharacterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let character = characterListViewModel.filteredCharacters[indexPath.row]
        let moveListViewController = container.makeMoveListViewController(character: character)
        Analytics.logEvent("Character_selected", parameters: ["name": character.nameEN])
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
