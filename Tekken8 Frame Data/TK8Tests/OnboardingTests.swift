@testable import TK8
import Combine
import UIKit
import XCTest

@MainActor
final class OnboardingTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "OnboardingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func test_firstLaunchAndPreviousAnnouncementReceiveNewContentOnlyUntilAcknowledged() {
        XCTAssertTrue(OnboardingManager.shouldShowOnboarding(defaults: defaults))
        defaults.set(2, forKey: "onboarding_shown_version")
        XCTAssertTrue(OnboardingManager.shouldShowOnboarding(defaults: defaults))
        OnboardingManager.markAsShown(defaults: defaults)
        XCTAssertFalse(OnboardingManager.shouldShowOnboarding(defaults: defaults))
        XCTAssertFalse(OnboardingManager.shouldShowOnboarding(defaults: UserDefaults(suiteName: suite)!))
        defaults.set(99, forKey: "onboarding_shown_version")
        OnboardingManager.markAsShown(defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: "onboarding_shown_version"), 99)
        XCTAssertFalse(OnboardingManager.shouldShowOnboarding(defaults: defaults))
    }

    func test_rootWaitsForAppearanceAndAcknowledgesOnePresentationAfterRepeatedCloseTaps() async {
        defaults.set(2, forKey: "onboarding_shown_version")
        let analytics = RecordingAnalyticsClient()
        let controller = makeRoot(analytics: analytics)
        controller.loadViewIfNeeded()
        XCTAssertNil(controller.presentedViewController)
        XCTAssertEqual(defaults.integer(forKey: "onboarding_shown_version"), 2)
        let window = makeWindow(controller)
        defer { window.isHidden = true }
        await settle()
        guard let onboarding = controller.presentedViewController as? OnboardingViewController else {
            XCTFail("Announcement should be presented once the root is visible")
            return
        }
        controller.viewDidAppear(false)
        controller.viewDidAppear(false)
        XCTAssertTrue(controller.presentedViewController === onboarding)
        XCTAssertEqual(defaults.integer(forKey: "onboarding_shown_version"), 2)
        XCTAssertFalse(analytics.events.contains(.memoEntryImpression()))
        let buttons = descendants(onboarding.view).compactMap { $0 as? UIButton }
        let done = buttons.first { $0.accessibilityIdentifier == "onboarding_done" }!
        done.sendActions(for: .touchUpInside)
        done.sendActions(for: .touchUpInside)
        await settle()
        XCTAssertNil(controller.presentedViewController)
        XCTAssertFalse(OnboardingManager.shouldShowOnboarding(defaults: defaults))
        XCTAssertEqual(analytics.events.filter { $0 == .screenViewed(.onboarding) }.count, 1)
        XCTAssertEqual(analytics.events.filter { $0 == .screenViewed(.characterList) }.count, 1)
        XCTAssertEqual(analytics.events.filter { $0 == .memoEntryImpression() }.count, 1)
        let restarted = makeRoot(analytics: RecordingAnalyticsClient())
        let restartedWindow = makeWindow(restarted)
        defer { restartedWindow.isHidden = true }
        await settle()
        XCTAssertNil(restarted.presentedViewController)
    }

    func test_interactiveDismissalRestoresUnderlyingScreenExactlyOnce() async {
        let parent = UIViewController()
        let window = makeWindow(parent)
        defer { window.isHidden = true }
        let analytics = RecordingAnalyticsClient()
        let onboarding = OnboardingManager.makeOnboardingVC(analytics: analytics, defaults: defaults)
        var dismissals = 0
        onboarding.onDismiss = { dismissals += 1; OnboardingManager.markAsShown(defaults: self.defaults) }
        parent.present(onboarding, animated: false)
        await settle()
        onboarding.viewDidAppear(false)
        let presentation = onboarding.presentationController!
        onboarding.dismiss(animated: false)
        onboarding.presentationControllerDidDismiss(presentation)
        onboarding.presentationControllerDidDismiss(presentation)
        XCTAssertEqual(dismissals, 1)
        XCTAssertFalse(OnboardingManager.shouldShowOnboarding(defaults: defaults))
        XCTAssertEqual(analytics.events.filter { $0 == .screenViewed(.onboarding) }.count, 1)
    }

    func test_smallDarkScreenScrollsFirstLaunchContentWithLargestTextAndKeepsDoneVisible() async {
        await verifyLayout(size: CGSize(width: 320, height: 568), category: .accessibilityExtraExtraExtraLarge, style: .dark, previousVersion: 0)
    }

    func test_lightUpdateScreenShowsOnlyNewFeaturesAndFitsInsideSheet() async {
        await verifyLayout(size: CGSize(width: 430, height: 932), category: .large, style: .light, previousVersion: 2)
    }

    private func verifyLayout(size: CGSize, category: UIContentSizeCategory, style: UIUserInterfaceStyle, previousVersion: Int) async {
        defaults.set(previousVersion, forKey: "onboarding_shown_version")
        let controller = OnboardingManager.makeOnboardingVC(analytics: RecordingAnalyticsClient(), defaults: defaults)
        let parent = UIViewController()
        controller.traitOverrides.preferredContentSizeCategory = category
        controller.traitOverrides.userInterfaceStyle = style
        parent.addChild(controller)
        parent.view.addSubview(controller.view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.didMove(toParent: parent)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        await settle()
        parent.view.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        let views = descendants(controller.view)
        let scroll = views.compactMap { $0 as? UIScrollView }.first!
        let done = views.first { $0.accessibilityIdentifier == "onboarding_done" }!
        let buttonFrame = done.convert(done.bounds, to: controller.view)
        XCTAssertGreaterThanOrEqual(buttonFrame.minY, 0)
        XCTAssertLessThanOrEqual(buttonFrame.maxY, size.height)
        XCTAssertGreaterThanOrEqual(buttonFrame.height, 44)
        XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1)
        if category.isAccessibilityCategory { XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height) }
        let labels = views.compactMap { $0 as? UILabel }
        let featureTitles = labels.filter { $0.accessibilityTraits.contains(.header) && $0.accessibilityIdentifier != "onboarding_title" }
        XCTAssertEqual(featureTitles.count, previousVersion == 0 ? 4 : 2)
        for label in labels {
            let frame = label.convert(label.bounds, to: controller.view)
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, size.width)
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
        }
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Onboarding-\(Int(size.width))-\(style.rawValue)-\(category.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeRoot(analytics: AnalyticsClient) -> CharacterListViewController {
        CharacterListViewController(characterListViewModel: EmptyOnboardingCharacters(), container: DIContainer(analytics: analytics),
            preference: CharacterLayoutPreference(manager: UserDefaultsManager(store: defaults)), analytics: analytics, onboardingDefaults: defaults)
    }

    private func makeWindow(_ controller: UIViewController) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller is CharacterListViewController ? UINavigationController(rootViewController: controller) : controller
        window.makeKeyAndVisible()
        return window
    }

    private func settle() async { try? await Task.sleep(nanoseconds: 600_000_000) }
    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
}

@MainActor
private final class EmptyOnboardingCharacters: CharacterFetchable, CharacterSelectable {
    var filteredCharacters: [Character] = []
    var characterImages: [String: UIImage] = [:]
    var filteredCharactersPublisher: AnyPublisher<[Character], Never> { Just([]).eraseToAnyPublisher() }
    var characterImagesPublisher: AnyPublisher<[String: UIImage], Never> { Just([:]).eraseToAnyPublisher() }
    func fetchCharacters() {}
    func filter(by keyword: String) {}
    func resetFilter() {}
    func loadImage(for character: Character) {}
    func image(for key: String) -> UIImage? { nil }
}
