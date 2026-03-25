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
    private var isPinned: Bool

    init(memoViewModel: MemoViewModel, characterListViewModel: any CharacterSelectable, memo: Memo?) {
        self.memoViewModel = memoViewModel
        self.characterListViewModel = characterListViewModel
        self.memo = memo
        selectedCharacterName = memo?.characterName ?? "common"
        isPinned = memo?.isPinned ?? false
        memoComposeView = MemoComposeView()
        characterSelectViewController = CharacterSelectViewController(viewModel: characterListViewModel)
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        memoComposeView.configure(memo: memo)
        memoComposeView.updateCharacter(
            name: selectedCharacterName ?? "common",
            image: characterListViewModel.image(for: selectedCharacterName ?? "")
        )
        memoComposeView.onCharacterChipTapped = { [weak self] in
            self?.characterSelectButtonTapped()
        }
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
        composeRightBarButton()
    }

    override func setupDelegation() {
        super.setupDelegation()
        characterSelectViewController.delegate = self
        memoComposeView.setTextViewDelegate(self)
    }

    @objc private func characterSelectButtonTapped() {
        navigationController?.pushViewController(characterSelectViewController, animated: true)
    }

    private func save() {
        guard !memoComposeView.titleContent.isEmpty ||
                !memoComposeView.bodyContent.isEmpty else { return }
        let title = memoComposeView.titleContent
        let body = title + "\n" + memoComposeView.bodyContent
        do {
            guard var memo else {
                // Create
                try memoViewModel.create(
                    character: selectedCharacterName ?? "common",
                    title: title,
                    body: body,
                    isPinned: isPinned
                )
                return
            }
            guard isUpdated(title: title, body: body) else { return }
            // Update
            memo.characterName = selectedCharacterName ?? "common"
            memo.title = title
            memo.body = body
            memo.isPinned = isPinned
            try memoViewModel.update(memo: memo)
        } catch {
            // 문제 발생 Alert
        }
    }

    private func isUpdated(title: String, body: String) -> Bool {
        return memo?.characterName != selectedCharacterName || memo?.title != title || memo?.body != body || memo?.isPinned != isPinned
    }

    private func composeRightBarButton() {
        if !memoComposeView.bodyContent.isEmpty || !memoComposeView.titleContent.isEmpty {
            navigationItem.rightBarButtonItem = generateEllipsisButton()
        } else {
            navigationItem.rightBarButtonItem = .none
        }
    }

    private func generateEllipsisButton() -> UIBarButtonItem {
        let menu = MemoMenuFactory.menu(isPinned: self.isPinned) {
            // Delete
            do {
                if let memo = self.memo {
                    try self.memoViewModel.delete(memos: [memo])
                }
                self.navigationController?.popViewController(animated: true)
            } catch {

            }
        } togglePin: {
            self.isPinned.toggle()
            self.composeRightBarButton()
        }
        let ellipsisButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: menu
        )
        return ellipsisButton
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MemoComposeViewController: Selectable {
    func didSelectCharacter(_ character: Character) {
        selectedCharacterName = character.nameEN
        memoComposeView.updateCharacter(
            name: character.nameEN,
            image: characterListViewModel.image(for: character.nameEN)
        )
    }
}

extension MemoComposeViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        memoComposeView.updatePlaceholders()
        composeRightBarButton()
    }

    func textView(_ textView: UITextView, shouldChangeTextInRanges ranges: [NSValue], replacementText text: String) -> Bool {
        // Title에서 Enter 입력 시 body로 이동
        if textView === memoComposeView.titleField, text == "\n" {
            memoComposeView.focusBody()
            return false
        }
        return true
    }
}
