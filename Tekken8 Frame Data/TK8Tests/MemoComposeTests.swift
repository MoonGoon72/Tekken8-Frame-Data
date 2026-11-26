//
//  MemoComposeTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest
import Combine
import UIKit

final class MemoComposeTests: XCTestCase {
    func test_newMemoAutomaticallyFocusesOnlyOnFirstAppearance() {
        var sut = MemoAutoFocusPolicy(isNewMemo: true)

        XCTAssertTrue(sut.shouldFocusOnAppearance())
        XCTAssertFalse(sut.shouldFocusOnAppearance())
    }

    func test_existingMemoNeverAutomaticallyFocuses() {
        var sut = MemoAutoFocusPolicy(isNewMemo: false)

        XCTAssertFalse(sut.shouldFocusOnAppearance())
        XCTAssertFalse(sut.shouldFocusOnAppearance())
    }
}

extension MemoComposeTests {
    @MainActor
    func test_doneShowsSavedMemoInReadingModeAndKeepsMarkdownSource() throws {
        let repository = MockMemoRepository()
        let sut = makeController(repository: repository)
        sut.loadViewIfNeeded()
        sut.setupNavigationBar()
        let screen = sut.view as! MemoComposeView

        XCTAssertTrue(screen.bodyField.isEditable)
        screen.titleField.text = "# Matchup"
        screen.bodyField.text = "## Punishes\n- jab\n"

        tapPrimaryButton(in: sut)

        XCTAssertFalse(screen.bodyField.isEditable)
        XCTAssertEqual(screen.titleField.text, "# Matchup")
        XCTAssertEqual(repository.memos.map(\.body), ["# Matchup\n## Punishes\n- jab\n"])
        let readingScrollView = try XCTUnwrap(screen.subviews.first { $0 is UIScrollView && !$0.isHidden })
        XCTAssertEqual(readingScrollView.subviews.compactMap { $0 as? UITextView }.first?.text, "Punishes\n• jab\n")

        tapPrimaryButton(in: sut)

        XCTAssertTrue(screen.bodyField.isEditable)
        XCTAssertEqual(screen.bodyField.text, "## Punishes\n- jab\n")
    }

    @MainActor
    func test_existingMemoStartsInReadingModeAndUnchangedDoneKeepsOriginalBytes() throws {
        let repository = MockMemoRepository()
        let memo = try repository.save(character: "common", title: "Matchup", body: "Matchup\r\n## Notes\r\n- jab", isPinned: false)
        let sut = makeController(repository: repository, memo: memo)
        sut.loadViewIfNeeded()
        let screen = sut.view as! MemoComposeView

        XCTAssertFalse(screen.bodyField.isEditable)
        tapPrimaryButton(in: sut)
        XCTAssertEqual(screen.bodyField.text, "## Notes\r\n- jab")
        tapPrimaryButton(in: sut)

        XCTAssertFalse(screen.bodyField.isEditable)
        XCTAssertEqual(repository.memos, [memo])
    }

    @MainActor
    func test_failedDoneKeepsEditingAndRetryCreatesOneMemo() {
        let repository = MockMemoRepository()
        repository.saveError = NSError(domain: "MemoComposeTests", code: 1)
        let sut = makeController(repository: repository)
        sut.loadViewIfNeeded()
        let screen = sut.view as! MemoComposeView
        screen.bodyField.text = "## Draft"

        tapPrimaryButton(in: sut)

        XCTAssertTrue(screen.bodyField.isEditable)
        XCTAssertEqual(screen.bodyField.text, "## Draft")
        XCTAssertTrue(repository.memos.isEmpty)

        repository.saveError = nil
        tapPrimaryButton(in: sut)

        XCTAssertFalse(screen.bodyField.isEditable)
        XCTAssertEqual(repository.memos.map(\.body), ["\n## Draft"])
    }

    @MainActor
    func test_clearingAnExistingMemoKeepsDraftAndDoesNotLogASave() throws {
        let repository = MockMemoRepository()
        let analytics = RecordingAnalyticsClient()
        let memo = try repository.save(character: "common", title: "Original", body: "Original\nBody", isPinned: false)
        let sut = makeController(repository: repository, memo: memo, analytics: analytics)
        sut.loadViewIfNeeded()
        let screen = sut.view as! MemoComposeView
        tapPrimaryButton(in: sut)
        screen.titleField.text = ""
        screen.bodyField.text = " "

        tapPrimaryButton(in: sut)

        XCTAssertTrue(screen.bodyField.isEditable)
        XCTAssertEqual(screen.bodyField.text, " ")
        XCTAssertEqual(repository.memos, [memo])
        XCTAssertEqual(analytics.events, [.memoComposeStarted(mode: .edit)])
    }

    @MainActor
    func test_onlyCompletedRemovalAutomaticallySaves() {
        let repository = MockMemoRepository()
        let sut = makeController(repository: repository)
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(sut, animated: false)
        sut.loadViewIfNeeded()
        let screen = sut.view as! MemoComposeView
        screen.bodyField.text = "- pending"

        sut.willMove(toParent: nil)
        sut.didMove(toParent: navigation)

        XCTAssertTrue(repository.memos.isEmpty)
        XCTAssertTrue(screen.bodyField.isEditable)
        XCTAssertEqual(screen.bodyField.text, "- pending")

        XCTAssertTrue(navigation.popViewController(animated: false) === sut)
        XCTAssertEqual(repository.memos.map(\.body), ["\n- pending"])
        sut.didMove(toParent: nil)
        XCTAssertEqual(repository.memos.count, 1)
    }

    @MainActor
    func test_cancellingInteractivePopKeepsEditorAndDoesNotSave() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let repository = MockMemoRepository()
        let sut = makeController(repository: repository)
        let navigation = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(200))

        navigation.pushViewController(sut, animated: false)
        try await Task.sleep(for: .milliseconds(200))
        let screen = sut.view as! MemoComposeView
        screen.bodyField.text = "- pending"
        let transition = MemoTestPopTransition()
        navigation.delegate = transition
        navigation.popViewController(animated: true)
        await fulfillment(of: [transition.started], timeout: 2)
        transition.interaction.update(0.25)
        transition.interaction.cancel()

        await fulfillment(of: [transition.completed], timeout: 3)

        XCTAssertTrue(transition.wasCancelled)
        XCTAssertTrue(navigation.topViewController === sut)
        XCTAssertTrue(screen.bodyField.isEditable)
        XCTAssertEqual(screen.bodyField.text, "- pending")
        XCTAssertTrue(repository.memos.isEmpty)
    }

    @MainActor
    func test_donePersistsCanonicallyEquivalentMarkdownInputVerbatim() throws {
        let repository = MockMemoRepository()
        let memo = try repository.save(character: "common", title: "Title", body: "Title\ncafé", isPinned: false)
        let sut = makeController(repository: repository, memo: memo)
        sut.loadViewIfNeeded()
        tapPrimaryButton(in: sut)
        let body = "cafe\u{301}"
        (sut.view as! MemoComposeView).bodyField.text = body

        tapPrimaryButton(in: sut)

        XCTAssertEqual(Array(repository.memos[0].body.utf8), Array("Title\n\(body)".utf8))
    }

    @MainActor
    private func tapPrimaryButton(in controller: UIViewController) {
        guard let button = controller.navigationItem.rightBarButtonItems?.first,
              let action = button.action else {
            return XCTFail("Expected a reading or editing action")
        }
        UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil)
    }

    @MainActor
    private func makeController(
        repository: MockMemoRepository,
        memo: Memo? = nil,
        analytics: RecordingAnalyticsClient = RecordingAnalyticsClient()
    ) -> MemoComposeViewController {
        let viewModel = MemoComposeViewModel(
            memoViewModel: MemoViewModel(memoRepository: repository),
            memo: memo,
            analytics: analytics
        )
        return MemoComposeViewController(
            composeViewModel: viewModel,
            characterListViewModel: MemoTestCharacters(),
            analytics: analytics,
            makeCharacterSelectViewController: { fatalError("Unexpected character selection") }
        )
    }
}

@MainActor
private final class MemoTestCharacters: CharacterSelectable {
    var filteredCharacters: [Character] = []
    var characterImages: [String: UIImage] = [:]
    var filteredCharactersPublisher: AnyPublisher<[Character], Never> { Just([]).eraseToAnyPublisher() }
    var characterImagesPublisher: AnyPublisher<[String: UIImage], Never> { Just([:]).eraseToAnyPublisher() }
    func filter(by keyword: String) {}
    func resetFilter() {}
    func loadImage(for character: Character) {}
    func image(for key: String) -> UIImage? { nil }
}

@MainActor
private final class MemoTestPopTransition: NSObject, UINavigationControllerDelegate, UIViewControllerAnimatedTransitioning {
    let interaction = UIPercentDrivenInteractiveTransition()
    private(set) var wasCancelled = false
    let started = XCTestExpectation(description: "Started interactive navigation transition")
    let completed = XCTestExpectation(description: "Completed interactive navigation transition")

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        operation == .pop ? self : nil
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        interaction
    }

    func transitionDuration(using context: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.2
    }

    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        started.fulfill()
        guard let from = context.view(forKey: .from), let to = context.view(forKey: .to) else {
            context.completeTransition(false)
            completed.fulfill()
            return
        }
        context.containerView.insertSubview(to, belowSubview: from)
        UIView.animate(withDuration: transitionDuration(using: context)) {
            from.alpha = 0
        } completion: { _ in
            from.alpha = 1
            self.wasCancelled = context.transitionWasCancelled
            context.completeTransition(!self.wasCancelled)
            self.completed.fulfill()
        }
    }
}
