//
//  MemoListViewController.swift
//  TK8
//

import Combine
import UIKit
import UniformTypeIdentifiers

final class MemoListViewController: BaseViewController {
    private typealias Snapshot = NSDiffableDataSourceSnapshot<MemoSection, Memo>
    private typealias memoDataSource = UICollectionViewDiffableDataSource<MemoSection, Memo>
    private typealias MemoComposeFactory = (Memo?) -> MemoComposeViewController

    private let memoListView: MemoListView
    private let searchController: UISearchController
    private let memoViewModel: MemoViewModel
    private var dataSource: memoDataSource?
    private let characterListViewModel: any CharacterSelectable
    private var importConfirmationURL: URL?

    private let makeMemoComposeViewController: MemoComposeFactory

    init(
        viewModel: MemoViewModel,
        characterListViewModel: any CharacterSelectable,
        makeMemoComposeViewController: @escaping (Memo?) -> MemoComposeViewController
    ) {
        self.memoListView = MemoListView()
        searchController = UISearchController(searchResultsController: nil)
        memoViewModel = viewModel
        self.characterListViewModel = characterListViewModel
        self.makeMemoComposeViewController = makeMemoComposeViewController
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
        let memoComposeViewController = makeMemoComposeViewController(nil)
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

    private func exportAllMemos() {
        do {
            let export = try memoViewModel.exportMemos()
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
            try export.data.write(to: fileURL, options: .atomic)
            presentShareSheet(fileURL: fileURL)
        } catch {
            presentAlert(title: "Export Failed".localized(), message: "Unable to export memos.".localized())
        }
    }

    private func importMemos() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [MemoBackupDocument.contentType],
            asCopy: true
        )
        picker.delegate = self
        present(picker, animated: true)
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
            let exportAllMemos = UIAction(title: "Export All Memos".localized(), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.exportAllMemos()
            }
            let importMemos = UIAction(title: "Import Memos".localized(), image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
                self?.importMemos()
            }
            let multiSelect = UIAction(title: "Select memo".localized(), image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.navigationController?.isToolbarHidden = false
                self?.toggleEditingMode()
                self?.toolbarItems = [
                    UIBarButtonItem(
                        title: "Select All".localized(),
                        style: .plain,
                        target: self,
                        action: #selector(self?.selectAllButtonTapped)
                    ),
                    UIBarButtonItem(systemItem: .flexibleSpace),
                    UIBarButtonItem(
                        title: "Delete".localized(),
                        style: .plain,
                        target: self,
                        action: #selector(self?.deleteButtonTapped)
                    )
                ]
            }
            let items = [exportAllMemos, importMemos, multiSelect]
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

    private func presentShareSheet(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activityViewController, animated: true)
    }

    private func presentImportConfirmation(fileURL: URL) {
        importConfirmationURL = fileURL
        let alert = UIAlertController(
            title: "Import Memos".localized(),
            message: "Memos from the selected file will be merged with your current memos. Newer memos with the same ID will replace older ones.".localized(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel) { [weak self] _ in
            self?.importConfirmationURL = nil
        })
        alert.addAction(UIAlertAction(title: "Import".localized(), style: .default) { [weak self] _ in
            guard let self, let url = self.importConfirmationURL else { return }
            self.importConfirmationURL = nil
            self.importMemos(from: url)
        })
        present(alert, animated: true)
    }

    private func importMemos(from fileURL: URL) {
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let result = try memoViewModel.importMemos(from: data)
            let message = String(
                format: "Imported %d new memos, updated %d memos, and skipped %d memos.".localized(),
                result.insertedCount,
                result.updatedCount,
                result.skippedCount
            )
            presentAlert(title: "Import Complete".localized(), message: message)
        } catch {
            presentAlert(title: "Import Failed".localized(), message: "Unable to import memos.".localized())
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
        present(alert, animated: true)
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
        let memoComposeViewController = makeMemoComposeViewController(memo)
        navigationController?.pushViewController(memoComposeViewController, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let cell = cell as? MemoCollectionViewCell
        cell?.setEditing(isEditing, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
                var memo = dataSource?.itemIdentifier(for: indexPath) else { return nil }

        let config = UIContextMenuConfiguration(
            previewProvider: {
                let previewProvider = self.makeMemoComposeViewController(memo)
            return previewProvider
        }) { _ in
            MemoMenuFactory.menu(isPinned: memo.isPinned) {
                // Delete
                do {
                    try self.memoViewModel.delete(memos: [memo])
                } catch {

                }
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

extension MemoListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        presentImportConfirmation(fileURL: fileURL)
    }
}

enum MemoSection: Int, CaseIterable {
    case pinned
    case general
}
