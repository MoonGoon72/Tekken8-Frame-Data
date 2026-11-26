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
    func test_doneShowsSavedMemoInReadingModeAndKeepsMarkdownSource() {
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
        XCTAssertEqual(screen.subviews.compactMap { $0 as? UITextView }
            .first { !$0.isHidden && $0 !== screen.titleField }?.text, "Punishes\n• jab\n")

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
    private func tapPrimaryButton(in controller: UIViewController) {
        guard let button = controller.navigationItem.rightBarButtonItems?.first,
              let action = button.action else {
            return XCTFail("Expected a reading or editing action")
        }
        UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil)
    }

    @MainActor
    private func makeController(repository: MockMemoRepository, memo: Memo? = nil) -> MemoComposeViewController {
        MemoComposeViewController(
            memoViewModel: MemoViewModel(memoRepository: repository),
            characterListViewModel: MemoTestCharacters(),
            memo: memo,
            analytics: RecordingAnalyticsClient(),
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
