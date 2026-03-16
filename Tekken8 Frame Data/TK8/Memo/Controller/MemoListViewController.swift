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
    private var filteredCancellable: AnyCancellable?
    private var dataSource: memoDataSource?

    init(viewModel: MemoViewModel) {
        self.memoListView = MemoListView()
        searchController = UISearchController(searchResultsController: nil)
        memoViewModel = viewModel
        
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
        filteredCancellable = memoViewModel.$memos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] memos in
                self?.updateSnapshot(for: memos)
            }
    }

    override func setupDataSource() {
        super.setupDataSource()
        setupDiffableDataSourece()
    }

    override func setupDelegation() {
        super.setupDelegation()
        searchController.delegate = self
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
        // 지워진 경우 뭘 할 것인지
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

        // 필터링 로직
    }
}

// MARK: - UICollectionViewDiffableDataSource conformance
private extension MemoListViewController {
    func setupDiffableDataSourece() {
        dataSource = memoDataSource(collectionView: memoListView.collectionView, cellProvider: { collectionView, indexPath, memo in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MemoCollectionViewCell.reuseIdentifier, for: indexPath) as? MemoCollectionViewCell else {
                return MemoCollectionViewCell()
            }
            cell.configure(memo: memo)
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

private enum Section {
    case main
    case pinned
}
