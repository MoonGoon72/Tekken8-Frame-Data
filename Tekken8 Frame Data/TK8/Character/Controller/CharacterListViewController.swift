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

    private let characterCollectionView: CharacterCollectionView
    private let characterListViewModel: any CharacterFetchable & CharacterSelectable
    private let container: DIContainer
    private let searchController: UISearchController
    private var dataSource: CharacterDataSource?
    private let analytics: AnalyticsClient
    private let searchAnalyticsTracker: SearchAnalyticsTracker
    private var hasLoadedCharacters = false
    private var shouldLogMemoEntryImpression = true

    private let preference: CharacterLayoutPreference
    private var currentLayoutMode: CharacterCollectionViewMode
    private lazy var layoutToggleButton = UIBarButtonItem(
        image: layoutToggleButtonImage(for: currentLayoutMode),
        style: .plain,
        target: self,
        action: #selector(layoutToggleButtonTapped)
    )

    init(
        characterListViewModel viewModel: any CharacterFetchable & CharacterSelectable,
        container: DIContainer,
        preference: CharacterLayoutPreference,
        analytics: AnalyticsClient
    ) {
        characterCollectionView = CharacterCollectionView()
        characterListViewModel = viewModel
        self.container = container
        self.preference = preference
        searchController = UISearchController(searchResultsController: nil)
        currentLayoutMode = preference.fetchLayoutMode()
        characterCollectionView.applyViewMode(currentLayoutMode)
        self.analytics = analytics
        searchAnalyticsTracker = SearchAnalyticsTracker(
            scope: .characterList,
            analytics: analytics
        )

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

    override func viewDidLoad() {
        super.viewDidLoad()
        if OnboardingManager.shouldShowOnboarding {
            let onboardingVC = OnboardingManager.makeOnboardingVC(analytics: analytics)
            onboardingVC.onDismiss = { [weak self] in self?.recordVisibleScreen() }
            present(onboardingVC, animated: true)
            OnboardingManager.markAsShown()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldLogMemoEntryImpression = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recordVisibleScreen()
    }

    private func recordVisibleScreen() {
        guard presentedViewController == nil else { return }
        analytics.log(.screenViewed(.characterList))
        if shouldLogMemoEntryImpression {
            analytics.log(.memoEntryImpression())
            shouldLogMemoEntryImpression = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchAnalyticsTracker.cancel()
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

        let memoButton = UIBarButtonItem(
            image: UIImage(systemName: "note.text"),
            style: .plain,
            target: self,
            action: #selector(memoButtonTapped)
        )
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        navigationItem.rightBarButtonItems = [settingsButton, layoutToggleButton, memoButton]
    }
    
    @objc private func settingsButtonTapped() {
        let settingsViewController = SettingViewController(analytics: analytics)
        navigationController?.pushViewController(settingsViewController, animated: true)
    }

    @objc private func memoButtonTapped() {
        analytics.log(.memoEntryTapped())
        let memoViewController = container.makeMemoListViewController(characterListViewModel: characterListViewModel)
        navigationController?.pushViewController(memoViewController, animated: true)
    }

    @objc private func layoutToggleButtonTapped() {
        currentLayoutMode = toggleMode()

        preference.updateLayoutMode(currentLayoutMode)
        characterCollectionView.applyViewMode(currentLayoutMode, animated: false)
        updateLayoutToggleButtonImage(for: currentLayoutMode)
        reloadVisibleCharacters()
    }

    private func toggleMode() -> CharacterCollectionViewMode {
        switch currentLayoutMode {
        case .list:
            return .grid
        case .grid:
            return .list
        }
    }

    private func reloadVisibleCharacters() {
        guard var snapshot = dataSource?.snapshot() else { return }
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    private func updateLayoutToggleButtonImage(for mode: CharacterCollectionViewMode) {
        layoutToggleButton.image = layoutToggleButtonImage(for: mode)
    }

    private func layoutToggleButtonImage(for mode: CharacterCollectionViewMode) -> UIImage? {
        switch mode {
        case .list:
            return UIImage(systemName: "square.grid.2x2")
        case .grid:
            return UIImage(systemName: "list.bullet")
        }
    }

    override func bindViewModel() {
        super.bindViewModel()
        
        characterListViewModel
            .filteredCharactersPublisher
            .sink { [weak self] filteredCharacters in
                self?.updateSnapshot(for: filteredCharacters)
            }
            .store(in: &subscriptionSet)
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
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsCancelButton = true
        searchController.searchBar.placeholder = Texts.placeholder.localized()
        navigationItem.searchController = searchController
    }
}

// MARK: UISearchController conformance

extension CharacterListViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        searchAnalyticsTracker.cancel()
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
        
        guard hasLoadedCharacters else {
            searchAnalyticsTracker.cancel()
            characterListViewModel.filter(by: text)
            return
        }

        searchAnalyticsTracker.textDidChange(to: text)
        characterListViewModel.filter(by: text)
    }
}

// MARK: - UICollectionViewDiffableDataSource method

private extension CharacterListViewController {
    func setupDiffableDataSource() {
        dataSource = CharacterDataSource(collectionView: characterCollectionView.characterCollectionView)
        {
            collectionView,
            indexPath,
            itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.characterHostingCell, for: indexPath)
            switch self.currentLayoutMode {
            case .list:
                cell.contentConfiguration = UIHostingConfiguration {
                    CharacterCell(
                        character: itemIdentifier,
                        characterImagePublisher: self.characterListViewModel.characterImagesPublisher,
                        characterImages: self.characterListViewModel.characterImages
                    )
                }
            case .grid:
                cell.contentConfiguration = UIHostingConfiguration {
                    CharacterGridCell(
                        character: itemIdentifier,
                        characterImagePublisher: self.characterListViewModel.characterImagesPublisher,
                        characterImages: self.characterListViewModel.characterImages
                    )
                }
            }

            return cell
        }
    }
    
    func updateSnapshot(for characters: [Character]) {
        if !characters.isEmpty {
            hasLoadedCharacters = true
        }

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(characters, toSection: .main)
        
        let attemptID = searchAnalyticsTracker.attemptID
        dataSource?.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.searchAnalyticsTracker.resultsApplied(count: characters.count, for: attemptID)
        }
    }
}

// MARK: - UICollectionViewDelegate Conformance

extension CharacterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let character = dataSource?.itemIdentifier(for: indexPath) else { return }
        let moveListViewController = container.makeMoveListViewController(character: character)
        analytics.log(.characterSelected(characterID: character.nameEN.lowercased()))
        navigationController?.pushViewController(moveListViewController, animated: true)
    }
}

private enum Section {
    case main
}

private enum Constants {
    static let characterHostingCell = "characterHostingCell"
}

private extension CharacterListViewController {
    enum Texts {
        static let placeholder = "Please enter the character name."
    }
}
