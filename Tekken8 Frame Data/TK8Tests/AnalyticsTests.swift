//
//  AnalyticsTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

@MainActor
final class AnalyticsTests: XCTestCase {
    func test_debugBuildCollectsOnlyWhenDebugViewLaunchArgumentIsPresent() {
        XCTAssertFalse(TK8AnalyticsCollectionPolicy.shouldCollect(isDebugBuild: true, launchArguments: []))
        XCTAssertTrue(TK8AnalyticsCollectionPolicy.shouldCollect(
            isDebugBuild: true,
            launchArguments: [TK8AnalyticsCollectionPolicy.debugLaunchArgument]
        ))
        XCTAssertTrue(TK8AnalyticsCollectionPolicy.shouldCollect(isDebugBuild: false, launchArguments: []))
    }

    func test_searchTracker_debouncesFastInputAndKeepsLatestResult() {
        let analytics = RecordingAnalyticsClient()
        let scheduler = ManualAnalyticsScheduler()
        let sut = SearchAnalyticsTracker(
            scope: .moveList,
            analytics: analytics,
            scheduler: scheduler
        )

        sut.textDidChange(to: "jin")
        sut.resultsApplied(count: 4)
        sut.textDidChange(to: "kazuya")
        sut.resultsApplied(count: 2)
        scheduler.runPending()

        XCTAssertEqual(analytics.events, [
            .searchResults(scope: .moveList, queryLength: 6, resultCount: 2)
        ])
    }

    func test_searchTracker_doesNotLogEmptyOrCancelledSearch() {
        let analytics = RecordingAnalyticsClient()
        let scheduler = ManualAnalyticsScheduler()
        let sut = SearchAnalyticsTracker(
            scope: .characterList,
            analytics: analytics,
            scheduler: scheduler
        )

        sut.textDidChange(to: "   ")
        sut.resultsApplied(count: 0)
        sut.textDidChange(to: "jin")
        sut.resultsApplied(count: 1)
        sut.cancel()
        scheduler.runPending()

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func test_searchTracker_deduplicatesSameConditionButAllowsReturningToIt() {
        let analytics = RecordingAnalyticsClient()
        let scheduler = ManualAnalyticsScheduler()
        let sut = SearchAnalyticsTracker(
            scope: .memoList,
            analytics: analytics,
            scheduler: scheduler
        )

        sut.textDidChange(to: "jin")
        sut.resultsApplied(count: 1)
        sut.textDidChange(to: "jin")
        sut.resultsApplied(count: 99)
        scheduler.runPending()

        sut.textDidChange(to: "kaz")
        sut.resultsApplied(count: 2)
        sut.textDidChange(to: "jin")
        sut.resultsApplied(count: 3)
        scheduler.runPending()

        XCTAssertEqual(analytics.events, [
            .searchResults(scope: .memoList, queryLength: 3, resultCount: 1),
            .searchResults(scope: .memoList, queryLength: 3, resultCount: 3)
        ])
    }

    func test_staleSnapshotCannotCompleteANewerSearchAttempt() {
        let analytics = RecordingAnalyticsClient()
        let scheduler = ManualAnalyticsScheduler()
        let sut = SearchAnalyticsTracker(scope: .moveList, analytics: analytics, scheduler: scheduler, characterID: "jin")
        sut.textDidChange(to: "a")
        let oldAttempt = sut.attemptID
        sut.textDidChange(to: "b")
        sut.resultsApplied(count: 100, for: oldAttempt)
        scheduler.runPending()
        XCTAssertTrue(analytics.events.isEmpty)
        sut.resultsApplied(count: 0, for: sut.attemptID)
        scheduler.runPending()
        XCTAssertEqual(analytics.events, [.searchResults(scope: .moveList, queryLength: 1, resultCount: 0, characterID: "jin")])
    }

    func test_snapshotCompletingAfterScreenExitDoesNotLog() {
        let analytics = RecordingAnalyticsClient()
        let scheduler = ManualAnalyticsScheduler()
        let sut = SearchAnalyticsTracker(scope: .memoList, analytics: analytics, scheduler: scheduler)
        sut.textDidChange(to: "a")
        let attempt = sut.attemptID
        sut.cancel()
        sut.resultsApplied(count: 3, for: attempt)
        scheduler.runPending()
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func test_persistAcknowledgementSurvivesRefreshFailureButNotWriteFailure() {
        let repository = MockMemoRepository()
        let sut = MemoViewModel(memoRepository: repository)
        repository.fetchError = NSError(domain: "test", code: 1)
        var persisted = 0
        XCTAssertThrowsError(try sut.create(character: "jin", title: "a", body: "a", isPinned: false) { persisted += 1 })
        XCTAssertEqual(persisted, 1)
        XCTAssertEqual(repository.memos.count, 1)
        repository.saveError = NSError(domain: "test", code: 2)
        XCTAssertThrowsError(try sut.create(character: "jin", title: "b", body: "b", isPinned: false) { persisted += 1 })
        XCTAssertEqual(persisted, 1)
        var memo = repository.memos[0]
        memo.body = "updated"
        XCTAssertThrowsError(try sut.update(memo: memo) { persisted += 1 })
        XCTAssertEqual(persisted, 2)
        XCTAssertEqual(repository.memos[0].body, "updated")
    }

    func test_analyticsEventsUseStableNamesAndDoNotContainRawSearchText() {
        let searchEvent = TK8AnalyticsEvent.searchResults(
            scope: .characterList,
            queryLength: 12,
            resultCount: 0
        )

        XCTAssertEqual(searchEvent.name, "search_results")
        XCTAssertEqual(searchEvent.parameters["query_length"], .integer(12))
        XCTAssertNil(searchEvent.parameters["keyword"])
        XCTAssertEqual(
            TK8AnalyticsEvent.characterSelected(characterID: "jin").name,
            "character_selected"
        )
    }

    func test_memoSaveDecisionDistinguishesCreateUpdateAndSkippedChanges() {
        let memo = Memo(
            id: UUID(),
            characterName: "common",
            title: "Title",
            body: "Title\nBody",
            isPinned: false,
            updatedAt: Date()
        )

        XCTAssertEqual(
            memoSaveDecision(
                memo: nil,
                selectedCharacterName: "common",
                title: "",
                body: "\n",
                isPinned: false
            ),
            .emptyContent
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: nil,
                selectedCharacterName: "common",
                title: " \t\n",
                body: "\n",
                isPinned: false
            ),
            .emptyContent
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: nil,
                selectedCharacterName: "common",
                title: "",
                body: " \n\n\t\n",
                isPinned: false
            ),
            .emptyContent
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: nil,
                selectedCharacterName: "common",
                title: "Title",
                body: "\n\n\n",
                isPinned: false
            ),
            .create
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: nil,
                selectedCharacterName: "common",
                title: "Title",
                body: "Title\nBody",
                isPinned: false
            ),
            .create
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: memo,
                selectedCharacterName: "common",
                title: "Title",
                body: "Title\nBody",
                isPinned: false
            ),
            .unchanged
        )
        XCTAssertEqual(
            memoSaveDecision(
                memo: memo,
                selectedCharacterName: "common",
                title: "Title",
                body: "Title\nChanged",
                isPinned: false
            ),
            .update
        )
    }
}

@MainActor
private final class ManualAnalyticsScheduler: AnalyticsScheduler {
    private var tasks: [ManualAnalyticsTask] = []

    @discardableResult
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> AnalyticsScheduledTask {
        let task = ManualAnalyticsTask(action: action)
        tasks.append(task)
        return task
    }

    func runPending() {
        let pendingTasks = tasks
        tasks.removeAll()
        pendingTasks.forEach { $0.runIfNeeded() }
    }
}

@MainActor
private final class ManualAnalyticsTask: AnalyticsScheduledTask {
    private let action: () -> Void
    private var isCancelled = false

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func cancel() {
        isCancelled = true
    }

    func runIfNeeded() {
        guard !isCancelled else { return }
        action()
    }
}
