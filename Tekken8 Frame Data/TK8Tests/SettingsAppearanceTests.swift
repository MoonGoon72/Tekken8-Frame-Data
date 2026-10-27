import Combine
import UIKit
import XCTest
@testable import TK8

@MainActor
final class SettingsAppearanceTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suite = "SettingsAppearanceTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func appearance() -> AppAppearance {
        AppAppearance(repository: DefaultAppThemeRepository(manager: UserDefaultsManager(store: defaults)))
    }

    private func root(_ appearance: AppAppearance) -> SettingViewController {
        SettingViewController(analytics: NoOpAnalyticsClient(),
            purchaseViewModel: SettingsPurchaseViewModel(purchases: AppearancePurchases()), appearance: appearance)
    }

    func testSettingsGroupsActionsAndMovesVersionsIntoFooter() {
        let controller = root(appearance())
        let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        let table = (controller.view as! SettingTableView).tableView
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 2)
        let themeCell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual((themeCell.contentConfiguration as? UIListContentConfiguration)?.secondaryText, AppTheme.dark.title)
        let footer = controller.tableView(table, viewForFooterInSection: 1)!
        XCTAssertTrue(descendants(footer).compactMap { ($0 as? UILabel)?.text }.contains { $0.contains(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") })
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertTrue(navigation.topViewController is PurchaseNoticeViewController)
    }

    func testMovesRestoreCompactNavigationAfterSettings() {
        let moves = MoveListViewController(character: Character(id: 1, nameEN: "Nina", nameKR: "니나", imageURL: ""),
            moveListViewModel: MoveListViewModel(moveRepository: AppearanceMoves()),
            container: DIContainer(analytics: NoOpAnalyticsClient()), analytics: NoOpAnalyticsClient(),
            moveVideoPlaybackURLProvider: UnusedAppearanceVideoProvider())
        let navigation = UINavigationController(rootViewController: moves)
        moves.setupNavigationBar()
        let settings = root(appearance())
        navigation.pushViewController(settings, animated: false)
        settings.setupNavigationBar()
        XCTAssertTrue(navigation.navigationBar.prefersLargeTitles)
        navigation.popViewController(animated: false)
        moves.setupNavigationBar()
        XCTAssertFalse(navigation.navigationBar.prefersLargeTitles)
    }

    func testThemeSheetImmediatelyUpdatesWindowAndSavedSelection() async {
        let appearance = appearance()
        let controller = root(appearance)
        let navigation = UINavigationController(rootViewController: controller)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        appearance.register(window)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        await settle()
        let table = (controller.view as! SettingTableView).tableView
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        await settle()
        let sheet = controller.presentedViewController as! UINavigationController
        await finishTransition(of: sheet)
        let picker = sheet.topViewController as! ThemeSelectionViewController
        picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        await finishTransition(of: sheet)
        await settle()
        XCTAssertEqual(window.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(self.appearance().theme, .light)
        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual((cell.contentConfiguration as? UIListContentConfiguration)?.secondaryText, AppTheme.light.title)
        XCTAssertNil(controller.presentedViewController)
        try? appearance.select(.system)
        await settle()
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
        XCTAssertEqual(window.traitCollection.userInterfaceStyle, scene.traitCollection.userInterfaceStyle)
    }

    func testSettingsLayoutsInBothThemesAndLargestText() async throws {
        for theme in [AppTheme.dark, .light] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let appearance = appearance()
                try appearance.select(theme)
                let controller = root(appearance)
                controller.traitOverrides.preferredContentSizeCategory = category
                let navigation = UINavigationController(rootViewController: controller)
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
                appearance.register(window)
                window.rootViewController = navigation
                window.makeKeyAndVisible()
                await settle()
                navigation.view.frame = window.bounds
                navigation.view.layoutIfNeeded()
                let table = (controller.view as! SettingTableView).tableView
                table.layoutIfNeeded()
                XCTAssertLessThanOrEqual(table.contentSize.width, table.bounds.width + 1)
                for cell in table.visibleCells {
                    for label in descendants(cell).compactMap({ $0 as? UILabel }) {
                        let rect = label.convert(label.bounds, to: cell)
                        XCTAssertGreaterThanOrEqual(rect.minX, -1)
                        XCTAssertLessThanOrEqual(rect.maxX, cell.bounds.width + 1)
                    }
                }
                let image = UIGraphicsImageRenderer(bounds: navigation.view.bounds).image { _ in
                    navigation.view.drawHierarchy(in: navigation.view.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Settings-\(theme.rawValue)-\(category.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
            }
        }
    }

    func testThemePickerFitsBothThemesWithLargestText() async throws {
        for theme in [AppTheme.dark, .light] {
            let appearance = appearance()
            try appearance.select(theme)
            let picker = ThemeSelectionViewController(appearance: appearance)
            picker.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            let navigation = UINavigationController(rootViewController: picker)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            appearance.register(window)
            window.rootViewController = navigation
            window.makeKeyAndVisible()
            await settle()
            navigation.view.layoutIfNeeded()
            XCTAssertEqual(picker.tableView.numberOfRows(inSection: 0), 3)
            picker.tableView.scrollToRow(at: IndexPath(row: 2, section: 0), at: .bottom, animated: false)
            picker.tableView.layoutIfNeeded()
            XCTAssertLessThanOrEqual(picker.tableView.contentSize.width, picker.tableView.bounds.width + 1)
            for cell in picker.tableView.visibleCells {
                for label in descendants(cell).compactMap({ $0 as? UILabel }) {
                    let rect = label.convert(label.bounds, to: cell)
                    XCTAssertGreaterThanOrEqual(rect.minX, -1)
                    XCTAssertLessThanOrEqual(rect.maxX, cell.bounds.width + 1)
                }
            }
            let image = UIGraphicsImageRenderer(bounds: navigation.view.bounds).image { _ in
                navigation.view.drawHierarchy(in: navigation.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "ThemePicker-\(theme.rawValue)-accessibility"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }

    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
    private func settle() async { try? await Task.sleep(for: .milliseconds(400)) }
    private func finishTransition(of controller: UIViewController) async {
        guard let coordinator = controller.transitionCoordinator else { return }
        let finished = expectation(description: "theme sheet transition completed")
        if coordinator.animate(alongsideTransition: nil, completion: { _ in finished.fulfill() }) {
            await fulfillment(of: [finished], timeout: 3)
        }
    }
}

@MainActor
private final class AppearancePurchases: AdRemovalPurchasing {
    let state = AdRemovalPurchaseState(entitlement: .notPurchased, displayPrice: "$2.99")
    var statePublisher: AnyPublisher<AdRemovalPurchaseState, Never> { Just(state).eraseToAnyPublisher() }
    func refresh() async {}
    func loadProduct() async {}
    func purchase() async -> AdRemovalActionResult { .cancelled }
    func restore() async -> AdRemovalActionResult { .noPurchases }
}

private struct AppearanceMoves: MoveRepository {
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
}

private struct UnusedAppearanceVideoProvider: MoveVideoPlaybackURLProviding {
    func playbackURL(for reference: MoveVideoReference) async throws -> URL { throw CocoaError(.fileNoSuchFile) }
}
