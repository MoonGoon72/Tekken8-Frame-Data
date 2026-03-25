//
//  OnBoardingManager.swift
//  TK8
//

import Foundation
import UIKit

enum OnboardingManager {
    private static let shownVersionKey = "onboarding_shown_version"
    private static let currentVersion = 1

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
                title: "프레임 데이터".localized(),
                description: "캐릭터를 탭하면 모든 기술의 발동, 가드, 히트, 카운터 프레임을 확인할 수 있습니다.".localized()
            ),
            OnboardingFeature(
                icon: "note.text",
                iconColor: UIColor(red: 0.98, green: 0.78, blue: 0.46, alpha: 1),
                title: "메모".localized(),
                description: "캐릭터별로 메모를 작성하고 수정할 수 있습니다. 중요한 메모는 고정해서 상단에 유지하세요.".localized()
            ),
            OnboardingFeature(
                icon: "hand.tap",
                iconColor: UIColor(red: 0.52, green: 0.72, blue: 0.92, alpha: 1),
                title: "롱프레스".localized(),
                description: "메모 셀을 길게 누르면 고정, 삭제, 공유 등의 메뉴가 나타납니다.".localized()
            ),
        ]
        return OnboardingViewController(features: features, version: "v\(version)")
    }
}
