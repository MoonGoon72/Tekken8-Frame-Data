import UIKit

final class MemoComposeViewController: BaseViewController {
    private let memoComposeView = MemoComposeView()
    private let composeViewModel: MemoComposeViewModel
    private let characterListViewModel: any CharacterSelectable
    private let makeCharacterSelectViewController: () -> CharacterSelectViewController
    private let analytics: AnalyticsClient
    private var autoFocusPolicy: MemoAutoFocusPolicy
    private var hasHandledDismissSave = false
    private var hasBeenPushed = false

    init(
        composeViewModel: MemoComposeViewModel,
        characterListViewModel: any CharacterSelectable,
        analytics: AnalyticsClient,
        makeCharacterSelectViewController: @escaping () -> CharacterSelectViewController
    ) {
        self.composeViewModel = composeViewModel
        self.characterListViewModel = characterListViewModel
        self.analytics = analytics
        autoFocusPolicy = MemoAutoFocusPolicy(isNewMemo: composeViewModel.memo == nil)
        self.makeCharacterSelectViewController = makeCharacterSelectViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = memoComposeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        memoComposeView.configure(memo: composeViewModel.memo)
        updateCharacter()
        memoComposeView.onCharacterChipTapped = { [weak self] in
            self?.openCharacterSelector()
        }
        updateMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.log(.screenViewed(.memoCompose))
        if autoFocusPolicy.shouldFocusOnAppearance() {
            memoComposeView.focusBody()
        }
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent is UINavigationController {
            hasBeenPushed = true
        } else if parent == nil, hasBeenPushed {
            saveAfterPop()
        }
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        composeRightBarButtons()
    }

    override func setupDelegation() {
        super.setupDelegation()
        memoComposeView.setTextViewDelegate(self)
    }

    private func openCharacterSelector() {
        guard composeViewModel.isEditing else { return }
        let controller = makeCharacterSelectViewController()
        controller.delegate = self
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func editButtonTapped() {
        composeViewModel.beginEditing()
        updateMode()
        memoComposeView.focusBody()
    }

    @objc private func doneButtonTapped() {
        let result = composeViewModel.finishEditing(title: memoComposeView.titleContent, body: memoComposeView.bodyContent)
        if result == .failed {
            showSaveError()
        } else if result == .empty {
            showAlert(title: "Enter a memo title or body".localized())
        } else {
            view.endEditing(true)
            memoComposeView.configure(memo: composeViewModel.memo)
            updateMode()
        }
    }

    private func saveAfterPop() {
        guard composeViewModel.isEditing, !hasHandledDismissSave else { return }
        hasHandledDismissSave = true
        _ = composeViewModel.save(title: memoComposeView.titleContent, body: memoComposeView.bodyContent)
    }

    private func showSaveError() {
        showAlert(title: "Could not save memo".localized())
    }

    private func showAlert(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close".localized(), style: .cancel))
        present(alert, animated: true)
    }

    private func updateMode() {
        memoComposeView.setEditing(composeViewModel.isEditing)
        composeRightBarButtons()
    }

    private func updateCharacter() {
        let name = composeViewModel.characterName
        memoComposeView.updateCharacter(name: name, image: characterListViewModel.image(for: name))
    }

    private func composeRightBarButtons() {
        let primaryAction = UIBarButtonItem(
            barButtonSystemItem: composeViewModel.isEditing ? .done : .edit,
            target: self,
            action: composeViewModel.isEditing ? #selector(doneButtonTapped) : #selector(editButtonTapped)
        )
        let hasContent = !memoComposeView.bodyContent.isEmpty || !memoComposeView.titleContent.isEmpty
        navigationItem.rightBarButtonItems = composeViewModel.memo != nil || hasContent
            ? [primaryAction, makeEllipsisButton()]
            : [primaryAction]
    }

    private func makeEllipsisButton() -> UIBarButtonItem {
        let menu = MemoMenuFactory.menu(isPinned: composeViewModel.isPinned) { [weak self] in
            guard let self else { return }
            do {
                try composeViewModel.delete()
                hasHandledDismissSave = true
                navigationController?.popViewController(animated: true)
            } catch {
                return
            }
        } togglePin: { [weak self] in
            guard let self else { return }
            if !composeViewModel.togglePin(title: memoComposeView.titleContent, body: memoComposeView.bodyContent) {
                showSaveError()
            }
            composeRightBarButtons()
        }
        return UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
    }
}

struct MemoAutoFocusPolicy {
    private let isNewMemo: Bool
    private var hasAppeared = false

    init(isNewMemo: Bool) {
        self.isNewMemo = isNewMemo
    }

    mutating func shouldFocusOnAppearance() -> Bool {
        defer { hasAppeared = true }
        return isNewMemo && !hasAppeared
    }
}

extension MemoComposeViewController: Selectable {
    func didSelectCharacter(_ character: Character) {
        composeViewModel.characterName = character.nameEN
        updateCharacter()
    }
}

extension MemoComposeViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        memoComposeView.updatePlaceholders()
        memoComposeView.scrollCaretToVisible(in: textView)
        composeRightBarButtons()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        memoComposeView.scrollCaretToVisible(in: textView)
    }

    func textView(_ textView: UITextView, shouldChangeTextInRanges ranges: [NSValue], replacementText text: String) -> Bool {
        if textView === memoComposeView.titleField, text == "\n" {
            memoComposeView.focusBody()
            return false
        }
        return true
    }
}
