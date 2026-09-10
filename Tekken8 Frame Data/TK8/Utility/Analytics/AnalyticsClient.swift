//
//  AnalyticsClient.swift
//  Tekken8 Frame Data
//

import FirebaseAnalytics
import Foundation

protocol AnalyticsClient: AnyObject {
    func log(_ event: TK8AnalyticsEvent)
}

enum TK8AnalyticsScreen: String, Equatable {
    case characterList = "character_list"
    case moveList = "move_list"
    case memoList = "memo_list"
    case memoCompose = "memo_compose"
    case moveFilter = "move_filter"
    case settings
    case characterSelect = "character_select"
    case onboarding
}

enum TK8AnalyticsSearchScope: String, Equatable {
    case characterList = "character_list"
    case moveList = "move_list"
    case memoList = "memo_list"
}

enum TK8AnalyticsMemoMode: String, Equatable {
    case create
    case edit
}

enum TK8AnalyticsFailureCode: String, Equatable {
    case repositoryError = "repository_error"
}

enum TK8AnalyticsSkipReason: String, Equatable {
    case emptyContent = "empty_content"
    case noChanges = "no_changes"
}

enum TK8AnalyticsValue: Equatable {
    case string(String)
    case integer(Int)
    case boolean(Bool)

    fileprivate var firebaseValue: Any {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return value
        case .boolean(let value):
            return value ? 1 : 0
        }
    }
}

struct TK8AnalyticsEvent: Equatable {
    let name: String
    let parameters: [String: TK8AnalyticsValue]

    static func screenViewed(_ screen: TK8AnalyticsScreen) -> Self {
        Self(
            name: "screen_view",
            parameters: [
                "firebase_screen": .string(screen.rawValue),
                "firebase_screen_class": .string(screen.rawValue)
            ]
        )
    }

    static func characterSelected(characterID: String) -> Self {
        Self(name: "character_selected", parameters: [
            "character_id": .string(characterID)
        ])
    }

    static func memoEntryImpression() -> Self {
        Self(name: "memo_entry_impression", parameters: [:])
    }

    static func memoEntryTapped() -> Self {
        Self(name: "memo_entry_tapped", parameters: [:])
    }

    static func searchResults(
        scope: TK8AnalyticsSearchScope,
        queryLength: Int,
        resultCount: Int,
        characterID: String? = nil
    ) -> Self {
        var parameters: [String: TK8AnalyticsValue] = [
            "search_scope": .string(scope.rawValue),
            "query_length": .integer(queryLength),
            "result_count": .integer(resultCount)
        ]
        if let characterID { parameters["character_id"] = .string(characterID) }
        return Self(name: "search_results", parameters: parameters)
    }

    static func moveListDisplayed(characterID: String, moveCount: Int) -> Self {
        Self(name: "move_list_displayed", parameters: [
            "character_id": .string(characterID),
            "move_count": .integer(moveCount)
        ])
    }

    static func moveListLoadFailed(
        characterID: String,
        failureCode: TK8AnalyticsFailureCode
    ) -> Self {
        Self(name: "move_list_load_failed", parameters: [
            "character_id": .string(characterID),
            "failure_code": .string(failureCode.rawValue)
        ])
    }

    static func filterOpened(characterID: String) -> Self {
        Self(name: "filter_opened", parameters: [
            "character_id": .string(characterID)
        ])
    }

    static func filterApplied(
        characterID: String,
        activeFilterCount: Int,
        sectionCount: Int,
        attributeCount: Int,
        startupRangeActive: Bool,
        guardRangeActive: Bool,
        resultCount: Int
    ) -> Self {
        Self(name: "filter_applied", parameters: [
            "character_id": .string(characterID),
            "active_filter_count": .integer(activeFilterCount),
            "section_count": .integer(sectionCount),
            "attribute_count": .integer(attributeCount),
            "startup_range_active": .boolean(startupRangeActive),
            "guard_range_active": .boolean(guardRangeActive),
            "result_count": .integer(resultCount)
        ])
    }

    static func filterReset(characterID: String, previousActiveFilterCount: Int) -> Self {
        Self(name: "filter_reset", parameters: [
            "character_id": .string(characterID),
            "previous_active_filter_count": .integer(previousActiveFilterCount)
        ])
    }

    static func memoComposeStarted(mode: TK8AnalyticsMemoMode) -> Self {
        Self(name: "memo_compose_started", parameters: [
            "memo_mode": .string(mode.rawValue)
        ])
    }

    static func memoSaveSucceeded(mode: TK8AnalyticsMemoMode) -> Self {
        Self(name: "memo_save_succeeded", parameters: [
            "memo_mode": .string(mode.rawValue)
        ])
    }

    static func memoSaveFailed(
        mode: TK8AnalyticsMemoMode,
        failureCode: TK8AnalyticsFailureCode
    ) -> Self {
        Self(name: "memo_save_failed", parameters: [
            "memo_mode": .string(mode.rawValue),
            "failure_code": .string(failureCode.rawValue)
        ])
    }

    static func memoSaveSkipped(
        mode: TK8AnalyticsMemoMode,
        reason: TK8AnalyticsSkipReason
    ) -> Self {
        Self(name: "memo_save_skipped", parameters: [
            "memo_mode": .string(mode.rawValue),
            "reason": .string(reason.rawValue)
        ])
    }
}

final class FirebaseAnalyticsClient: AnalyticsClient {
    func log(_ event: TK8AnalyticsEvent) {
        var parameters: [String: Any] = [:]
        for (key, value) in event.parameters {
            parameters[key] = value.firebaseValue
        }
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }
}

final class NoOpAnalyticsClient: AnalyticsClient {
    func log(_ event: TK8AnalyticsEvent) {}
}

final class RecordingAnalyticsClient: AnalyticsClient {
    private(set) var events: [TK8AnalyticsEvent] = []

    func log(_ event: TK8AnalyticsEvent) {
        events.append(event)
    }
}

enum TK8AnalyticsCollectionPolicy {
    static var isEnabled: Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return false }
        #if DEBUG
        return shouldCollect(isDebugBuild: true, launchArguments: ProcessInfo.processInfo.arguments)
        #else
        return true
        #endif
    }

    static let debugLaunchArgument = "-FIRAnalyticsDebugEnabled"

    static func shouldCollect(isDebugBuild: Bool, launchArguments: [String]) -> Bool {
        guard isDebugBuild else { return true }
        return launchArguments.contains(debugLaunchArgument)
    }
}
