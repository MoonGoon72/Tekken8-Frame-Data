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

    func testFailedWritePreservesVisibleAndSavedTheme() {
        let appearance = AppAppearance(repository: FailingThemeRepository())
        let window = UIWindow()
        appearance.register(window)
        XCTAssertThrowsError(try appearance.select(.light))
        XCTAssertEqual(appearance.theme, .dark)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
    }

}

private struct FailingThemeRepository: AppThemeRepository {
    var theme: AppTheme { .dark }
    func save(_ theme: AppTheme) throws { throw CocoaError(.fileWriteUnknown) }
}
