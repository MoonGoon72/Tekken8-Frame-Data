//
//  MemoComposeViewController.swift
//  TK8
//

import Foundation
import UIKit

final class MemoComposeViewController: BaseViewController {
    private let memoComposeView: MemoComposeView
    private let memoViewModel: MemoViewModel
    private var memo: Memo?
    private var selectedCharacterName: String?

    init(memoViewModel: MemoViewModel, memo: Memo?) {
        self.memoViewModel = memoViewModel
        self.memo = memo
        memoComposeView = MemoComposeView()

        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        memoComposeView.configure(memo: memo)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        memoComposeView.activateTextView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        save()
    }

    override func loadView() {
        super.loadView()
        view = memoComposeView
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        navigationController?.navigationBar.tintColor = .tkBackground
        navigationController?.title = memo?.characterName ?? "Common"

        let characterSelectButton = UIBarButtonItem(
            title: "Select Character",
            style: .plain,
            target: self,
            action: #selector(characterSelectButtonTapped)
        )
        let ellipsisButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: self,
            action: #selector(ellipsisButtonTapped)
        )
        navigationItem.rightBarButtonItems = [ellipsisButton, characterSelectButton]
    }

    @objc private func characterSelectButtonTapped() {
        
    }

    @objc private func ellipsisButtonTapped() {

    }

    private func save() {
        guard !memoComposeView.content.isEmpty else { return }
        let title = titleParser()
        do {
            guard var memo else {
                // Create
                try memoViewModel.create(character: selectedCharacterName ?? "common", title: title, body: memoComposeView.content)
                return
            }
            // Update
            memo.title = title
            memo.body = memoComposeView.content
            try memoViewModel.update(memo: memo)
        } catch {
            // 문제 발생 Alert
        }
    }

    private func titleParser() -> String {
        memoComposeView.content.components(separatedBy: .newlines).first ?? ""
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
