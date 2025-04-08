//
//  CharacterListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/23/25.
//

import SwiftUI
import UIKit

final class CharacterListViewController: UIViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    
    private let supabaseManager = SupabaseManager()
    private let characterListView: CharacterListView
    private let characterViewModel = CharacterListViewModel()
    private var dataSource: CharacterDataSource?
    private var characters: [Character] = []
    private var filteredCharacters: [Character] = []
    
    init() {
        characterListView = CharacterListView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        characterListView = CharacterListView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDiffalbeDataSource()
        setupSearchController()
    }
    
    override func loadView() {
        super.loadView()
        
        view = characterListView
        fetchCharacters()
    }
    
    private func fetchCharacters() {
        Task {
            do {
                let fetchedCharacters: [Character] = try await supabaseManager.fetchCharacter()
                characters = fetchedCharacters
                updateSnapshot(for: characters)
                
                for character in characters {
                    characterViewModel.loadImage(for: character)
                }
            } catch {
                NSLog("❌ Error fetching characters: \(error)")
            }
        }
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension CharacterListViewController {
    func setupDiffalbeDataSource() {
        dataSource = CharacterDataSource( collectionView: characterListView.characterCollectionView)
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

// MARK: - UISearchController Delegate

extension CharacterListViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        updateSnapshot(for: characters)
    }
}

// MARK: - UISearchBar Delegate

extension CharacterListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UISearchResultsUpdating

extension CharacterListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        if text.isEmpty {
            updateSnapshot(for: characters)
        } else {
            filteredCharacters = characters.filter { $0.name.contains(text)}
            updateSnapshot(for: filteredCharacters)
        }
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
