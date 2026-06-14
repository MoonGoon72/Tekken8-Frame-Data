//
//  OnBoardingManager.swift
//  TK8
//

import Foundation
import UIKit

enum OnboardingManager {
    private static let shownVersionKey = "onboarding_shown_version"
    private static let currentVersion = 2

    static var shouldShowOnboarding: Bool {
        let shownVersion = UserDefaults.standard.integer(forKey: shownVersionKey)
        return shownVersion < currentVersion
    }

    static func markAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: shownVersionKey)
    }

    static func makeOnboardingVC() -> OnboardingViewController {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let features: [OnboardingFeature] = [
            OnboardingFeature(
                icon: "list.bullet.rectangle",
                iconColor: UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1),
                title: "Frame Data".localized(),
                description: "Tap a character to view the activation, guard, hit, and counter frames for all their moves.".localized()
            ),
            OnboardingFeature(
                icon: "note.text",
                iconColor: UIColor(red: 0.98, green: 0.78, blue: 0.46, alpha: 1),
                title: "MEMOS".localized(),
                description: "You can create and edit notes for each character. Pin important notes to keep them at the top.".localized()
            ),
            OnboardingFeature(
                icon: "hand.tap",
                iconColor: UIColor(red: 0.52, green: 0.72, blue: 0.92, alpha: 1),
                title: "Long press".localized(),
                description: "When you press and hold a note cell, a menu with options such as Pin, Delete will appear.".localized()
            ),
            OnboardingFeature(
                icon: "line.3.horizontal.decrease.circle",
                iconColor: UIColor(red: 0.52, green: 0.72, blue: 0.92, alpha: 1),
                title: "Filtering".localized(),
                description: "You can filter moves by applying filtering conditions.".localized()
            )
        ]
        return OnboardingViewController(features: features, version: "v\(version)")
    }
}
