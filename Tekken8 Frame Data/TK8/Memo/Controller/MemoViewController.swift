//
//  MemoViewController.swift
//  TK8
//

import UIKit

final class MemoViewController: BaseViewController {
    private let memoView: MemoView
    private let searchController: UISearchController

    init() {
        self.memoView = MemoView()
        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        view = memoView
    }

    override func setupDelegation() {
        super.setupDelegation()

        searchController.delegate = self
    }

    override func setupNavigationBar() {
        setupSearchController()
    }
}

// MARK: - MemoViewController setup Conformance

private extension MemoViewController {
    func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.automaticallyShowsCancelButton = true
        searchController.searchBar.placeholder = "Search."
        navigationItem.searchController = searchController
    }
}

// MARK: - UISearchBar conformance

extension MemoViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        // 지워진 경우 뭘 할 것인지
    }
}

extension MemoViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension MemoViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }

        // 필터링 로직
    }
}
