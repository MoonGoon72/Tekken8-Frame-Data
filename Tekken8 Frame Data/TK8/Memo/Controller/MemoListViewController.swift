//
//  MemoListViewController.swift
//  TK8
//

import Combine
import UIKit

final class MemoListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<MemoSection, Memo>
    private typealias memoDataSource = UICollectionViewDiffableDataSource<MemoSection, Memo>
    
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
        composeRightBarButtons()
    }

    @objc private func composeButtonTapped() {
        let memoComposeViewController = MemoComposeViewController(
            memoViewModel: memoViewModel,
            characterListViewModel: characterListViewModel,
            memo: nil
        )
        navigationController?.pushViewController(memoComposeViewController, animated: true)
    }

    @objc private func deleteButtonTapped() {
        let willDeleteMemos = memoListView.collectionView.indexPathsForSelectedItems?.compactMap {
            dataSource?.itemIdentifier(for: $0)
        }
        do {
            try memoViewModel.delete(memos: willDeleteMemos ?? [])
        } catch {

        }
        toggleEditingMode()
        navigationController?.isToolbarHidden = true
    }

    @objc private func doneButtonTapped() {
        memoListView.collectionView.indexPathsForSelectedItems?.forEach {
            memoListView.collectionView.deselectItem(at: $0, animated: true)
        }
        toggleEditingMode()
        navigationController?.isToolbarHidden = true
        composeRightBarButtons()
    }

    @objc private func selectAllButtonTapped() {
        dataSource?.snapshot().itemIdentifiers.forEach {
            let indexPath = dataSource?.indexPath(for: $0)
            memoListView.collectionView.selectItem(
                at: indexPath,
                animated: true,
                scrollPosition: []
            )
        }
    }

    func toggleEditingMode() {
        isEditing.toggle()
        memoListView.collectionView.allowsMultipleSelection = isEditing
        memoListView.collectionView.visibleCells.compactMap { $0 as? MemoCollectionViewCell }.forEach {
            $0.setEditing(isEditing, animated: true)
        }
        composeRightBarButtons()
    }

    private func composeRightBarButtons() {
        let menuItems: [UIAction] = {
            let multiSelect = UIAction(title: "메모 선택".localized(), image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.navigationController?.isToolbarHidden = false
                self?.toggleEditingMode()
                self?.toolbarItems = [
                    UIBarButtonItem(
                        title: "전체 선택".localized(),
                        style: .plain,
                        target: self,
                        action: #selector(self?.selectAllButtonTapped)
                    ),
                    UIBarButtonItem(systemItem: .flexibleSpace),
                    UIBarButtonItem(
                        title: "삭제".localized(),
                        style: .plain,
                        target: self,
                        action: #selector(self?.deleteButtonTapped)
                    )
                ]
            }
            let items = [multiSelect]
            return items
        }()
        let composeButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(composeButtonTapped)
        )
        let ellipsisButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: UIMenu(options: .displayInline, children: menuItems)
        )
        let doneButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark.circle"),
            style: .plain,
            target: self,
            action: #selector(doneButtonTapped)
        )
        if isEditing {
            navigationItem.rightBarButtonItems = [doneButton]
        } else {
            navigationItem.rightBarButtonItems = [ellipsisButton, composeButton]
        }
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
            cell.setEditing(self.isEditing, animated: true)
            return cell
        })
        dataSource?.supplementaryViewProvider = {
            collectionView,
            kind,
            indexPath in
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MemoSectionHeaderView.reuseIdentifier,
                for: indexPath
            ) as? MemoSectionHeaderView

            let section = self.dataSource?.snapshot().sectionIdentifiers[indexPath.section]
            header?.configure(section: section ?? .general)
            return header
        }
    }

    func updateSnapshot(for memos: [Memo]) {
        var snapshot = Snapshot()
        let pinned = memos.filter { $0.isPinned }
        let general = memos.filter { !$0.isPinned }
        if !pinned.isEmpty {
            snapshot.appendSections([.pinned])
            snapshot.appendItems(pinned, toSection: .pinned)
        }

        snapshot.appendSections([.general])
        snapshot.appendItems(general, toSection: .general)

        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate Conformance

extension MemoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing { return }
        let memo = dataSource?.itemIdentifier(for: indexPath)
        let memoComposeViewController = MemoComposeViewController(
            memoViewModel: memoViewModel,
            characterListViewModel: characterListViewModel,
            memo: memo
        )
        navigationController?.pushViewController(memoComposeViewController, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let cell = cell as? MemoCollectionViewCell
        cell?.setEditing(isEditing, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
                var memo = dataSource?.itemIdentifier(for: indexPath) else { return nil }

        let config = UIContextMenuConfiguration(previewProvider: {
            let previewProvider = MemoComposeViewController(
                memoViewModel: self.memoViewModel,
                characterListViewModel: self.characterListViewModel,
                memo: memo
            )
            return previewProvider
        }) { _ in
            MemoMenuFactory.menu(isPinned: memo.isPinned) {
                // Delete
                do {
                    try self.memoViewModel.delete(memos: [memo])
                } catch {

                }
            } share: {
                // Share
            } togglePin: {
                memo.isPinned.toggle()
                do {
                    try self.memoViewModel.update(memo: memo)
                } catch {

                }
            }
        }
        return config
    }
}

enum MemoSection: Int, CaseIterable {
    case pinned
    case general
}
