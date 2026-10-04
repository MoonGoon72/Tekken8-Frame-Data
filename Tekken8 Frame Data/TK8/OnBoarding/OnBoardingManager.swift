//
//  OnBoardingManager.swift
//  TK8
//

import Foundation
import UIKit

enum OnboardingManager {
    private static let shownVersionKey = "onboarding_shown_version"
    // Increment only when the announcement content changes, independently of app patch versions.
    private static let currentVersion = 3

    static func shouldShowOnboarding(defaults: UserDefaults = .standard) -> Bool {
        let shownVersion = defaults.integer(forKey: shownVersionKey)
        return shownVersion < currentVersion
    }

    static func markAsShown(defaults: UserDefaults = .standard) {
        let previousVersion = defaults.integer(forKey: shownVersionKey)
        defaults.set(max(previousVersion, currentVersion), forKey: shownVersionKey)
    }

    static func makeOnboardingVC(analytics: AnalyticsClient, defaults: UserDefaults = .standard) -> OnboardingViewController {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let isFirstLaunch = defaults.integer(forKey: shownVersionKey) == 0
        var features: [OnboardingFeature] = [
            OnboardingFeature(
                icon: "play.rectangle",
                iconColor: .tkRed,
                title: "Move videos".localized(),
                description: "Tap a move with the play icon in the move list to see its details and watch how it works.".localized()
            ),
            OnboardingFeature(
                icon: "line.3.horizontal.decrease.circle",
                iconColor: .tkRed,
                title: "Find moves by frame".localized(),
                description: "Type a startup or guard frame value. Search for an exact value, a minimum, a maximum, or a range.".localized()
            )
        ]
        if isFirstLaunch {
            features += [
                OnboardingFeature(
                    icon: "list.bullet.rectangle",
                    iconColor: .tkRed,
                    title: "Frame Data".localized(),
                    description: "Tap a character to view the activation, guard, hit, and counter frames for all their moves.".localized()
                ),
                OnboardingFeature(
                    icon: "note.text",
                    iconColor: .tkRed,
                    title: "MEMOS".localized(),
                    description: "You can create and edit notes for each character. Pin important notes to keep them at the top.".localized()
                )
            ]
        }
        return OnboardingViewController(features: features, version: "v\(version)", isFirstLaunch: isFirstLaunch, analytics: analytics)
    }
}
