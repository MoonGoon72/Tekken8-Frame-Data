//
//  MemoComposeViewController.swift
//  TK8
//

import Foundation
import UIKit

final class MemoComposeViewController: BaseViewController {
    private let memoComposeView: MemoComposeView
    private let memoViewModel: MemoViewModel
    private let characterListViewModel: any CharacterSelectable
    private let characterSelectViewController: CharacterSelectViewController
    private var memo: Memo?
    private var selectedCharacterName: String?

    init(memoViewModel: MemoViewModel, characterListViewModel: any CharacterSelectable, memo: Memo?) {
        self.memoViewModel = memoViewModel
        self.characterListViewModel = characterListViewModel
        self.memo = memo
        selectedCharacterName = memo?.characterName ?? "common"
        memoComposeView = MemoComposeView()
        characterSelectViewController = CharacterSelectViewController(viewModel: characterListViewModel)
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
        if isMovingFromParent { save() }
    }

    override func loadView() {
        super.loadView()
        view = memoComposeView
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        updateTitle(for: selectedCharacterName)

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

    override func setupDelegation() {
        super.setupDelegation()
        characterSelectViewController.delegate = self
    }

    @objc private func characterSelectButtonTapped() {
        navigationController?.pushViewController(characterSelectViewController, animated: true)
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
            memo.characterName = selectedCharacterName ?? "common"
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

    private func updateTitle(for title: String?) {
        navigationItem.title = title ?? "Common"
    }
}

extension MemoComposeViewController: Selectable {
    func didSelectCharacter(_ character: Character) {
        selectedCharacterName = character.nameEN
        updateTitle(for: selectedCharacterName)
    }
}
