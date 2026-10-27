import Combine
import UIKit
import XCTest
@testable import TK8

@MainActor
final class AppAppearanceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() async throws {
        suite = "AppAppearanceTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    private func makeAppearance() -> AppAppearance {
        AppAppearance(repository: DefaultAppThemeRepository(manager: UserDefaultsManager(store: defaults)))
    }

    func testNewAndInvalidPreferencesDefaultToDark() throws {
        XCTAssertEqual(makeAppearance().theme, .dark)
        try UserDefaultsManager(store: defaults).update("unexpected-value", forKey: "app_theme")
        XCTAssertEqual(makeAppearance().theme, .dark)
    }

    func testChoiceUpdatesRegisteredWindowsAndSurvivesRecreation() throws {
        let appearance = makeAppearance()
        let first = UIWindow()
        let second = UIWindow()
        appearance.register(first)
        appearance.register(second)
        XCTAssertEqual(first.overrideUserInterfaceStyle, .dark)
        try appearance.select(.light)
        XCTAssertEqual(first.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(second.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(makeAppearance().theme, .light)
        let reopened = UIWindow()
        makeAppearance().register(reopened)
        XCTAssertEqual(reopened.overrideUserInterfaceStyle, .light)
    }

    func testSystemChoiceRemovesOverrideAndPersists() throws {
        let appearance = makeAppearance()
        let window = UIWindow()
        appearance.register(window)
        try appearance.select(.system)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
        XCTAssertEqual(makeAppearance().theme, .system)
    }

    func testSystemFollowingIsNotOverriddenByBundleAppearance() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle"),
                     "Saved theme controls the default; Info.plist must allow system appearance")
    }

    func testFailedWritePreservesVisibleAndSavedTheme() {
        let appearance = AppAppearance(repository: FailingThemeRepository())
        let window = UIWindow()
        appearance.register(window)
        XCTAssertThrowsError(try appearance.select(.light))
        XCTAssertEqual(appearance.theme, .dark)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
    }

    func testTextRolesHaveReadableContrastInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for surface in ["TKBackground", "TKSurface", "TKMutedSurface"] {
                let background = try XCTUnwrap(UIColor(named: surface)).resolvedColor(with: traits)
                for foreground in ["TKPrimaryText", "TKSecondaryText", "TKActionText"] {
                    let text = try XCTUnwrap(UIColor(named: foreground)).resolvedColor(with: traits)
                    XCTAssertGreaterThanOrEqual(contrast(text, background), 4.5, "\(foreground) on \(surface) in \(style)")
                }
            }
        }
    }

    func testNavigationAndNoticeActionTextHasReadableContrastInBothThemes() throws {
        let navigationBar = UINavigationBar()
        AppNavigationStyle.apply(to: navigationBar)
        let notice = AdRemovalNoticeView(onLearnMore: {}, onClose: {})
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let learnMore = try XCTUnwrap(descendants(notice).first {
            $0.accessibilityIdentifier == "ad_removal_notice_learn_more"
        } as? UIButton)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let navigationText = try XCTUnwrap(navigationBar.tintColor).resolvedColor(with: traits)
            let linkText = try XCTUnwrap(learnMore.tintColor).resolvedColor(with: traits)
            XCTAssertGreaterThanOrEqual(contrast(navigationText, UIColor.tkBackground.resolvedColor(with: traits)), 4.5,
                                        "Small navigation action text must remain readable in \(style)")
            XCTAssertGreaterThanOrEqual(contrast(linkText, UIColor.tkSurface.resolvedColor(with: traits)), 4.5,
                                        "Notice action text must remain readable in \(style)")
        }
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func testJudgmentLabelsHaveReadableContrastOnTheirTintedBackgrounds() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let surface = try XCTUnwrap(UIColor(named: "TKSurface")).resolvedColor(with: traits)
            for name in ["TKNegative", "TKWarning", "TKInfo", "TKPositive", "TKSpecial"] {
                let color = try XCTUnwrap(UIColor(named: name)).resolvedColor(with: traits)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                surface.getRed(&sr, green: &sg, blue: &sb, alpha: &a)
                let tint = UIColor(red: r * 0.2 + sr * 0.8, green: g * 0.2 + sg * 0.8,
                                   blue: b * 0.2 + sb * 0.8, alpha: 1)
                XCTAssertGreaterThanOrEqual(contrast(color, tint), 4.5, "\(name) badge in \(style)")
            }
        }
    }
}

private struct FailingThemeRepository: AppThemeRepository {
    var theme: AppTheme { .dark }
    func save(_ theme: AppTheme) throws { throw CocoaError(.fileWriteUnknown) }
}
