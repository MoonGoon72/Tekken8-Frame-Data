@testable import TK8
import Combine
import UIKit
import XCTest

final class MemoAutosaveRecoveryTests: XCTestCase {
    @MainActor
    func test_failedNewMemoShowsAlertAndClosedDraftCanBeRecoveredFromRecreatedList() async throws {
        let repository = MockMemoRepository()
        let drafts = MemoDraftStore()
        let analytics = RecordingAnalyticsClient()
        let list = makeList(repository: repository, drafts: drafts, analytics: analytics)
        let navigation = UINavigationController(rootViewController: list)
        let window = try show(navigation)
        defer { window.isHidden = true }
        try await awaitAppearance(of: list)

        try tapComposeButton(in: list)
        let firstEditor = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: firstEditor)
        let firstView = try XCTUnwrap(firstEditor.view as? MemoComposeView)
        firstView.titleField.text = "Punish notes"
        let rawBody = "## Paul\r\n- café\n"
        firstView.bodyField.text = rawBody
        repository.saveError = CocoaError(.fileWriteOutOfSpace)

        XCTAssertTrue(navigation.popViewController(animated: false) === firstEditor)
        let firstAlert = try await awaitAlert(on: list)
        XCTAssertEqual(drafts.drafts.first?.rawBody, rawBody)
        XCTAssertTrue(navigation.topViewController === list)
        XCTAssertEqual(firstAlert.title, "Could not save memo".localized())
        XCTAssertEqual(firstAlert.actions.map(\.title), ["Return to Editing".localized(), "Close".localized()])
        XCTAssertEqual(firstAlert.actions.last?.style, .cancel)
        XCTAssertTrue(repository.memos.isEmpty)
        XCTAssertTrue(analytics.events.contains(.memoSaveFailed(mode: .create, failureCode: .repositoryError)))
        XCTAssertFalse(analytics.events.contains(.memoSaveSucceeded(mode: .create)))
        let firstDraftID = try XCTUnwrap(drafts.drafts.first?.id)

        try await dismissAlert(on: list)
        XCTAssertTrue(navigation.topViewController === list)
        XCTAssertEqual(drafts.drafts.map(\.id), [firstDraftID])
        XCTAssertTrue(list.navigationItem.rightBarButtonItems?.contains {
            $0.accessibilityLabel == "Memo Drafts".localized()
        } == true)

        try tapComposeButton(in: list)
        let secondEditor = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: secondEditor)
        let secondView = try XCTUnwrap(secondEditor.view as? MemoComposeView)
        secondView.bodyField.text = "Second draft"
        XCTAssertTrue(navigation.popViewController(animated: false) === secondEditor)
        _ = try await awaitAlert(on: list)
        try await dismissAlert(on: list)
        XCTAssertEqual(drafts.drafts.map(\.rawBody), ["Second draft", rawBody])
        let secondDraftID = try XCTUnwrap(drafts.drafts.first?.id)

        let recreatedList = makeList(repository: repository, drafts: drafts, analytics: analytics)
        navigation.setViewControllers([recreatedList], animated: false)
        try await awaitAppearance(of: recreatedList)
        XCTAssertTrue(recreatedList.navigationItem.rightBarButtonItems?.contains {
            $0.accessibilityLabel == "Memo Drafts".localized()
        } == true)
        recreatedList.reopenDraft(id: firstDraftID)
        let recovered = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: recovered)
        let recoveredView = try XCTUnwrap(recovered.view as? MemoComposeView)
        XCTAssertTrue(recoveredView.bodyField.isEditable)
        XCTAssertEqual(recoveredView.titleField.text, "Punish notes")
        XCTAssertEqual(Array(recoveredView.bodyField.text.utf8), Array(rawBody.utf8))

        repository.saveError = nil
        try tapDoneButton(in: recovered)
        XCTAssertFalse(recoveredView.bodyField.isEditable)
        let savedMemo = try XCTUnwrap(repository.memos.first)
        XCTAssertEqual(Array(savedMemo.body.utf8), Array("Punish notes\n\(rawBody)".utf8))
        XCTAssertEqual(drafts.drafts.map(\.id), [secondDraftID])
        XCTAssertEqual(analytics.events.filter { $0 == .memoSaveSucceeded(mode: .create) }.count, 1)
    }

    @MainActor
    func test_failedExistingMemoStillOpensReadOnlyAndDraftRetryPreservesUUIDAndRawBody() async throws {
        let repository = MockMemoRepository()
        let baseline = try repository.save(character: "jin", title: "Old", body: "Old\nOriginal", isPinned: false)
        let drafts = MemoDraftStore()
        let analytics = RecordingAnalyticsClient()
        let list = makeList(repository: repository, drafts: drafts, analytics: analytics)
        let navigation = UINavigationController(rootViewController: list)
        let window = try show(navigation)
        defer { window.isHidden = true }
        try await awaitAppearance(of: list)

        let search = try XCTUnwrap(list.navigationItem.searchController)
        search.isActive = true
        try await awaitAppearance(of: search)
        search.searchBar.text = "Old"
        list.updateSearchResults(for: search)
        let collectionView = try XCTUnwrap((list.view as? MemoListView)?.collectionView)
        let indexPath = IndexPath(item: 0, section: 0)
        list.collectionView(collectionView, didSelectItemAt: indexPath)
        let editor = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: editor)
        let composeView = try XCTUnwrap(editor.view as? MemoComposeView)
        XCTAssertFalse(composeView.bodyField.isEditable)
        try tapDoneButton(in: editor)
        composeView.titleField.text = "Jin"
        composeView.bodyField.text = "# Matchup\n- 2,1"
        repository.updateError = CocoaError(.fileWriteOutOfSpace)

        XCTAssertTrue(navigation.popViewController(animated: false) === editor)
        try await awaitCondition("Expected the failed update to retain its draft") {
            drafts.drafts.first?.id == baseline.id
        }
        _ = try await awaitAlert(on: list)
        XCTAssertFalse(search.isActive)
        XCTAssertEqual(repository.memos, [baseline])
        XCTAssertEqual(drafts.drafts.first?.id, baseline.id)
        XCTAssertTrue(analytics.events.contains(.memoSaveFailed(mode: .edit, failureCode: .repositoryError)))
        XCTAssertFalse(analytics.events.contains(.memoSaveSucceeded(mode: .edit)))

        try await dismissAlert(on: list)
        list.collectionView(collectionView, didSelectItemAt: indexPath)
        let reader = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: reader)
        let readingView = try XCTUnwrap(reader.view as? MemoComposeView)
        XCTAssertFalse(readingView.bodyField.isEditable)
        XCTAssertEqual(readingView.titleField.text, baseline.title)
        XCTAssertEqual(readingView.bodyField.text, baseline.rawBody)
        XCTAssertTrue(navigation.popViewController(animated: false) === reader)
        try await awaitAppearance(of: list)
        XCTAssertEqual(drafts.drafts.map(\.id), [baseline.id])

        list.reopenDraft(id: baseline.id)
        let recovered = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: recovered)
        let recoveredView = try XCTUnwrap(recovered.view as? MemoComposeView)
        XCTAssertTrue(recoveredView.bodyField.isEditable)
        XCTAssertEqual(recoveredView.titleField.text, "Jin")
        XCTAssertEqual(recoveredView.bodyField.text, "# Matchup\n- 2,1")

        repository.updateError = nil
        XCTAssertTrue(navigation.popViewController(animated: false) === recovered)
        try await awaitCondition("Expected the recovered editor to save after the pop") {
            analytics.events.contains(.memoSaveSucceeded(mode: .edit))
        }
        XCTAssertTrue(navigation.topViewController === list)
        XCTAssertEqual(repository.memos.map(\.id), [baseline.id])
        XCTAssertEqual(repository.memos.first?.body, "Jin\n# Matchup\n- 2,1")
        XCTAssertTrue(drafts.drafts.isEmpty)
        XCTAssertEqual(analytics.events.filter { $0 == .memoSaveSucceeded(mode: .edit) }.count, 1)
    }

    @MainActor
    func test_restoredDraftKeepsOriginalUUIDWhenLoadedListMissesMemoAndRefreshFails() async throws {
        let repository = MockMemoRepository()
        let drafts = MemoDraftStore()
        let analytics = RecordingAnalyticsClient()
        let list = makeList(repository: repository, drafts: drafts, analytics: analytics)
        let navigation = UINavigationController(rootViewController: list)
        let window = try show(navigation)
        defer { window.isHidden = true }
        try await awaitAppearance(of: list)

        let original = try repository.save(character: "common", title: "Old", body: "Old\nBody", isPinned: false)
        drafts.retain(makeDraft(for: original))
        repository.fetchError = CocoaError(.fileReadUnknown)

        list.reopenDraft(id: original.id)
        let recovered = try XCTUnwrap(navigation.topViewController as? MemoComposeViewController)
        try await awaitAppearance(of: recovered)
        try tapDoneButton(in: recovered)

        XCTAssertEqual(repository.memos.map(\.id), [original.id])
        XCTAssertEqual(repository.memos.first?.body, "Retry\n- Draft")
        XCTAssertTrue(drafts.drafts.isEmpty)
        XCTAssertTrue(analytics.events.contains(.memoSaveSucceeded(mode: .edit)))
        XCTAssertFalse(analytics.events.contains(.memoSaveSucceeded(mode: .create)))
    }

    @MainActor
    func test_listDeletionClearsOnlyMatchingDraftEvenWhenRefreshFails() throws {
        let repository = MockMemoRepository()
        let first = try repository.save(character: "common", title: "First", body: "First\nBody", isPinned: false)
        let second = try repository.save(character: "common", title: "Second", body: "Second\nBody", isPinned: false)
        let drafts = MemoDraftStore()
        drafts.retain(makeDraft(for: first))
        drafts.retain(makeDraft(for: second))
        let list = makeList(repository: repository, drafts: drafts, analytics: RecordingAnalyticsClient())
        list.loadViewIfNeeded()
        repository.fetchError = CocoaError(.fileReadUnknown)

        list.deleteMemos([first])

        XCTAssertEqual(repository.memos.map(\.id), [second.id])
        XCTAssertEqual(drafts.drafts.map(\.id), [second.id])
    }

    func test_bulkDeletionRemovesCompletedWritesFromListWhenALaterWriteFails() throws {
        let repository = MockMemoRepository()
        let first = try repository.save(character: "common", title: "First", body: "Body", isPinned: false)
        let second = try repository.save(character: "common", title: "Second", body: "Body", isPinned: false)
        let viewModel = MemoViewModel(memoRepository: repository)
        try viewModel.fetch()

        XCTAssertThrowsError(try viewModel.delete(memos: [first, second]) { _ in
            repository.deleteError = CocoaError(.fileWriteOutOfSpace)
        })

        XCTAssertEqual(repository.memos, [second])
        XCTAssertEqual(viewModel.memos, [second])
        XCTAssertEqual(viewModel.filteredMemos, [second])
    }

    @MainActor
    func test_composeDeletionClearsPendingDraftOnlyAfterRepositorySucceeds() throws {
        let repository = MockMemoRepository()
        let memo = try repository.save(character: "common", title: "Old", body: "Old\nBody", isPinned: false)
        let drafts = MemoDraftStore()
        drafts.retain(makeDraft(for: memo))
        let viewModel = MemoComposeViewModel(
            memoViewModel: MemoViewModel(memoRepository: repository),
            memo: memo,
            analytics: RecordingAnalyticsClient(),
            draftStore: drafts
        )
        repository.deleteError = CocoaError(.fileWriteOutOfSpace)

        XCTAssertThrowsError(try viewModel.delete())
        XCTAssertEqual(drafts.drafts.map(\.id), [memo.id])
        XCTAssertEqual(repository.memos, [memo])

        repository.deleteError = nil
        repository.fetchError = CocoaError(.fileReadUnknown)
        XCTAssertNoThrow(try viewModel.delete())
        XCTAssertTrue(drafts.drafts.isEmpty)
        XCTAssertTrue(repository.memos.isEmpty)
    }

    private func makeDraft(for memo: Memo) -> MemoDraft {
        MemoDraft(
            id: memo.id,
            memo: memo,
            title: "Retry",
            rawBody: "- Draft",
            characterName: memo.characterName,
            isPinned: memo.isPinned
        )
    }

    @MainActor
    private func makeList(
        repository: MockMemoRepository,
        drafts: MemoDraftStore,
        analytics: RecordingAnalyticsClient
    ) -> MemoListViewController {
        let viewModel = MemoViewModel(memoRepository: repository)
        let characters = RecoveryTestCharacters()
        return MemoListViewController(
            viewModel: viewModel,
            characterListViewModel: characters,
            analytics: analytics,
            draftStore: drafts
        ) { memo, draft in
            MemoComposeViewController(
                composeViewModel: MemoComposeViewModel(
                    memoViewModel: viewModel, memo: memo, analytics: analytics, draft: draft, draftStore: drafts
                ),
                characterListViewModel: characters,
                analytics: analytics,
                makeCharacterSelectViewController: { fatalError("Unexpected character selection") }
            )
        }
    }

    @MainActor
    private func show(_ navigation: UINavigationController) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        return window
    }

    @MainActor
    private func awaitAppearance(of controller: UIViewController) async throws {
        try await awaitCondition("Expected the controller to finish appearing") {
            controller.viewIfLoaded?.window != nil && controller.transitionCoordinator == nil
        }
    }

    @MainActor
    private func awaitCondition(_ message: String, condition: () -> Bool) async throws {
        for _ in 0..<50 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(40))
        }
        XCTFail(message)
    }

    @MainActor
    private func awaitAlert(on list: MemoListViewController) async throws -> UIAlertController {
        try await awaitCondition("Expected the memo save alert to finish appearing") {
            (list.presentedViewController as? UIAlertController)?.isBeingPresented == false
        }
        return try XCTUnwrap(list.presentedViewController as? UIAlertController)
    }

    @MainActor
    private func dismissAlert(on list: MemoListViewController) async throws {
        let alert = try await awaitAlert(on: list)
        await withCheckedContinuation { continuation in
            alert.dismiss(animated: false) { continuation.resume() }
        }
    }

    @MainActor
    private func tapComposeButton(in list: MemoListViewController) throws {
        let button = try XCTUnwrap(list.navigationItem.rightBarButtonItems?.last)
        let action = try XCTUnwrap(button.action)
        XCTAssertTrue(UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil))
    }

    @MainActor
    private func tapDoneButton(in editor: MemoComposeViewController) throws {
        let button = try XCTUnwrap(editor.navigationItem.rightBarButtonItems?.first)
        let action = try XCTUnwrap(button.action)
        XCTAssertTrue(UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil))
    }
}

@MainActor
private final class RecoveryTestCharacters: CharacterSelectable {
    var filteredCharacters: [Character] = []
    var characterImages: [String: UIImage] = [:]
    var filteredCharactersPublisher: AnyPublisher<[Character], Never> { Just([]).eraseToAnyPublisher() }
    var characterImagesPublisher: AnyPublisher<[String: UIImage], Never> { Just([:]).eraseToAnyPublisher() }
    func filter(by keyword: String) {}
    func resetFilter() {}
    func loadImage(for character: Character) {}
    func image(for key: String) -> UIImage? { nil }
}
