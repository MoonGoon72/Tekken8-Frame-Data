//
//  CharacterListViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/23/25.
//

import SwiftUI
import UIKit

class CharacterListViewController: UIViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    
    private let supabaseManager = SupabaseManager()
    private var dataSource: CharacterDataSource?
    private let characterListView: CharacterListView
    private var characters: [Character] = []
    
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
                updateSnapshot()
            } catch {
                print("❌ Error fetching characters: \(error)")
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
                CharacterCell(character: itemIdentifier)
            }
            return cell
        }
    }
    
    func updateSnapshot() {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(characters)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
}

private enum Section {
    case main
}
