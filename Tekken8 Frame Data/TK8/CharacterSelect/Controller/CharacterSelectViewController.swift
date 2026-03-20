//
//  CharacterSelectViewController.swift
//  TK8
//

import Combine
import Foundation
import SwiftUI
import UIKit

protocol Selectable: AnyObject {
    func didSelectCharacter(_ name: Character)
}

private enum Section {
    case main
}

final class CharacterSelectViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Character>
    private typealias CharacterDataSource = UICollectionViewDiffableDataSource<Section, Character>
    
    private let viewModel: any CharacterSelectable
    private let characterSelectView: CharacterCollectionView
    private let searchController: UISearchController
    private var dataSource: CharacterDataSource?
    weak var delegate: Selectable?

    init(viewModel: any CharacterSelectable) {
        self.viewModel = viewModel
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

    override func bindViewModel() {
        super.bindViewModel()

        viewModel.filteredCharactersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] characters in
                self?.updateSnapshot(for: characters)
            }
            .store(in: &subscriptionSet)
    }

    override func setupDataSource() {
        super.setupDataSource()
        setupDiffableDataSource()
    }

    override func setupDelegation() {
        super.setupDelegation()
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
        viewModel.resetFilter()
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }

        viewModel.filter(by: text)
    }
}

// MARK: - UICollectionViewDelegate

extension CharacterSelectViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectCharacter(viewModel.filteredCharacters[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
}

private extension CharacterSelectViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource(collectionView: characterSelectView.characterCollectionView) { collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CharacterCell.reuseIdentifier, for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration{
                CharacterCell(character: itemIdentifier, characterImagePublisher: self.viewModel.characterImagesPublisher)
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
