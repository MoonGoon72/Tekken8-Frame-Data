//
//  MemoListViewController.swift
//  TK8
//

import Combine
import UIKit

final class MemoListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Memo>
    private typealias memoDataSource = UICollectionViewDiffableDataSource<Section, Memo>
    
    private let memoListView: MemoListView
    private let searchController: UISearchController
    private let memoViewModel: MemoViewModel
    private var dataSource: memoDataSource?
    private let characterListViewModel: any CharacterSelectable

    init(viewModel: MemoViewModel, characterListViewModel: any CharacterSelectable) {
        self.memoListView = MemoListView()
        searchController = UISearchController(searchResultsController: nil)
        memoViewModel = viewModel
        self.characterListViewModel = characterListViewModel

        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        view = memoListView
        do {
            try memoViewModel.fetch()
        } catch {
            // TODO: 패치 실패를 알림
        }
    }

    override func bindViewModel() {
        memoViewModel.$filteredMemos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memos in
                self?.updateSnapshot(for: memos)
            }
            .store(in: &subscriptionSet)
    }

    override func setupDataSource() {
        super.setupDataSource()
        setupDiffableDataSourece()
    }

    override func setupDelegation() {
        super.setupDelegation()
        searchController.delegate = self
        memoListView.collecionViewDelegate(self)
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        setupSearchController()
        let createMemoButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(createMemoButtonTapped)
        )
        navigationItem.rightBarButtonItems = [
            createMemoButton
        ]
    }

    @objc private func createMemoButtonTapped() {
        let memoComposeViewController = MemoComposeViewController(
            memoViewModel: memoViewModel,
            characterListViewModel: characterListViewModel,
            memo: nil
        )
        navigationController?.pushViewController(memoComposeViewController, animated: true)
    }
}

// MARK: - MemoViewController setup Conformance

private extension MemoListViewController {
    func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsCancelButton = true
        searchController.searchBar.placeholder = "Search."
        navigationItem.searchController = searchController
    }
}

// MARK: - UISearchBar conformance

extension MemoListViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        memoViewModel.resetFilter()
    }
}

extension MemoListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension MemoListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        memoViewModel.filter(by: text)
    }
}

// MARK: - UICollectionViewDiffableDataSource conformance
private extension MemoListViewController {
    func setupDiffableDataSourece() {
        dataSource = memoDataSource(collectionView: memoListView.collectionView, cellProvider: { collectionView, indexPath, memo in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MemoCollectionViewCell.reuseIdentifier, for: indexPath) as? MemoCollectionViewCell else {
                return MemoCollectionViewCell()
            }
            cell.configure(memo: memo, image: self.characterListViewModel.image(for: memo.characterName))
            return cell
        })
    }

    func updateSnapshot(for memos: [Memo]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(memos, toSection: .main)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate Conformance

extension MemoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memo = memoViewModel.filteredMemos[indexPath.row]
        let memoComposeViewCOntroller = MemoComposeViewController(
            memoViewModel: memoViewModel,
            characterListViewModel: characterListViewModel,
            memo: memo
        )
        navigationController?.pushViewController(memoComposeViewCOntroller, animated: true)
    }
}

private enum Section {
    case main
    case pinned
}
