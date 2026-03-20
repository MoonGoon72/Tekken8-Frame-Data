//
//  CharacterSelectViewController.swift
//  TK8
//

import Combine
import Foundation
import SwiftUI
import UIKit

protocol CharacterSelectable: AnyObject {
    func didSelectCharacter(_ character: Character)
}

private enum Section {
    case main
}

final class CharacterSelectViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    
    private let characters: [Character]
    private var filteredCharacters: [Character] = []
    private let characterSelectView: CharacterCollectionView
    private let searchController: UISearchController
    private var cancellable: AnyCancellable?
    private var dataSource: CharacterDataSource?
    weak var delegate: CharacterSelectable?

    init(characters: [Character]) {
        self.characters = characters
        filteredCharacters = characters
        characterSelectView = CharacterCollectionView()
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = characterSelectView
    }

    override func setupDataSource() {
        setupDiffableDataSource()
    }

    override func setupDelegation() {
        characterSelectView.setCollectionViewDelegate(self)
        searchController.delegate = self
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        setupSearchController()
    }
}

// MARK: - UISearchControllerDelegate, UISearchResultsUpdating, UISearchController Conformance

extension CharacterSelectViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsCancelButton = true
        searchController.searchBar.placeholder = "캐릭터 이름을 입력해주세요.".localized()
        navigationItem.searchController = searchController
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        filteredCharacters = characters
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }

        filteredCharacters = characters.filter { $0.nameEN.contains(text) || $0.nameKR.contains(text) }
    }
}

// MARK: - UICollectionViewDelegate

extension CharacterSelectViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectCharacter(filteredCharacters[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
}

private extension CharacterSelectViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource(collectionView: characterSelectView.characterCollectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CharacterCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration{ CharacterCell(character: itemIdentifier, viewModel: <#T##CharacterListViewModel#>) }
        }
    }
}
