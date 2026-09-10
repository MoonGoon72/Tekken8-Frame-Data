//
//  SearchAnalyticsTracker.swift
//  Tekken8 Frame Data
//

import Foundation

protocol AnalyticsScheduledTask: AnyObject {
    func cancel()
}

protocol AnalyticsScheduler {
    @discardableResult
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> AnalyticsScheduledTask
}

private final class DispatchAnalyticsScheduledTask: AnalyticsScheduledTask {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}

final class DispatchAnalyticsScheduler: AnalyticsScheduler {
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> AnalyticsScheduledTask {
        let workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return DispatchAnalyticsScheduledTask(workItem: workItem)
    }
}

@MainActor
final class SearchAnalyticsTracker {
    private let analytics: AnalyticsClient
    private let scheduler: AnalyticsScheduler
    private let scope: TK8AnalyticsSearchScope
    private let debounceInterval: TimeInterval
    private let characterID: String?
    private(set) var attemptID: UUID?

    private var currentKeyword: String?
    private var hasAppliedResults = false
    private var hasLoggedCurrentAttempt = false
    private var scheduledTask: AnalyticsScheduledTask?

    init(
        scope: TK8AnalyticsSearchScope,
        analytics: AnalyticsClient,
        scheduler: AnalyticsScheduler = DispatchAnalyticsScheduler(),
        debounceInterval: TimeInterval = 0.5,
        characterID: String? = nil
    ) {
        self.scope = scope
        self.analytics = analytics
        self.scheduler = scheduler
        self.debounceInterval = debounceInterval
        self.characterID = characterID
    }

    func textDidChange(to rawKeyword: String) {
        let keyword = rawKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            cancel()
            return
        }

        // UISearchResultsUpdating can call back repeatedly for the same condition.
        guard keyword != currentKeyword else { return }

        scheduledTask?.cancel()
        scheduledTask = nil
        currentKeyword = keyword
        attemptID = UUID()
        hasAppliedResults = false
        hasLoggedCurrentAttempt = false
    }

    func resultsApplied(count: Int, for appliedAttemptID: UUID?) {
        guard let appliedAttemptID, appliedAttemptID == attemptID else { return }
        resultsApplied(count: count)
    }

    func resultsApplied(count: Int) {
        guard let keyword = currentKeyword,
              !hasAppliedResults,
              !hasLoggedCurrentAttempt else { return }

        hasAppliedResults = true
        scheduledTask = scheduler.schedule(after: debounceInterval) { [weak self] in
            guard let self,
                  self.currentKeyword == keyword,
                  self.hasAppliedResults,
                  !self.hasLoggedCurrentAttempt else { return }

            self.analytics.log(.searchResults(
                scope: self.scope,
                queryLength: keyword.count,
                resultCount: count,
                characterID: self.characterID
            ))
            self.hasLoggedCurrentAttempt = true
            self.scheduledTask = nil
        }
    }

    func cancel() {
        scheduledTask?.cancel()
        scheduledTask = nil
        currentKeyword = nil
        attemptID = nil
        hasAppliedResults = false
        hasLoggedCurrentAttempt = false
    }

    deinit {
        scheduledTask?.cancel()
    }
}
