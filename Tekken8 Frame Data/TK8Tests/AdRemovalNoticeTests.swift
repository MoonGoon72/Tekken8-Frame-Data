import Combine
import GoogleMobileAds
import UIKit
import XCTest
@testable import TK8

@MainActor
final class AdRemovalNoticeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var purchases: NoticePurchases!

    override func setUp() async throws {
        suite = "AdRemovalNoticeTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        purchases = NoticePurchases()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        purchases = nil
    }

    private func makeViewModel() -> AdRemovalNoticeViewModel {
        AdRemovalNoticeViewModel(purchases: purchases,
            repository: DefaultAdRemovalNoticeRepository(manager: UserDefaultsManager(store: defaults)))
    }

    func testOnlyConfirmedNonPurchaseIsEligibleAndChangesAreImmediate() {
        let model = makeViewModel()
        XCTAssertFalse(model.isEligible)
        for entitlement: AdRemovalEntitlement in [.unknown, .adFree, .checking] {
            purchases.subject.send(AdRemovalPurchaseState(entitlement: entitlement))
            XCTAssertFalse(model.isEligible)
        }
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        XCTAssertTrue(model.isEligible)
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .adFree))
        XCTAssertFalse(model.isEligible)
    }

    func testViewingDoesNotConsumeButActionPersistsAcrossRecreation() {
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        let model = makeViewModel()
        XCTAssertTrue(model.isEligible)
        XCTAssertTrue(makeViewModel().isEligible, "Merely creating/showing the notice must not consume it")
        model.consume()
        XCTAssertFalse(model.isEligible)
        XCTAssertFalse(makeViewModel().isEligible)
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .unknown))
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        XCTAssertFalse(model.isEligible)
    }

    func testNoticeButtonsHaveSeparateActionsAndAccessibleTouchTargets() {
        var learned = 0
        var closed = 0
        let notice = AdRemovalNoticeView(onLearnMore: { learned += 1 }, onClose: { closed += 1 })
        notice.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        notice.layoutIfNeeded()
        let buttons = descendants(notice).compactMap { $0 as? UIButton }
        let learn = buttons.first { $0.accessibilityIdentifier == "ad_removal_notice_learn_more" }!
        let close = buttons.first { $0.accessibilityIdentifier == "ad_removal_notice_close" }!
        learn.sendActions(for: .touchUpInside)
        XCTAssertEqual(learned, 1)
        XCTAssertEqual(closed, 0)
        close.sendActions(for: .touchUpInside)
        XCTAssertEqual(closed, 1)
        for button in buttons {
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
        }
        XCTAssertNotNil(close.accessibilityLabel)
    }

    func testLargestTextFitsNarrowNoticeWithoutOverlappingActions() {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        child.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        child.overrideUserInterfaceStyle = .dark
        let notice = AdRemovalNoticeView(onLearnMore: {}, onClose: {})
        child.view.addSubview(notice)
        notice.frame = CGRect(x: 0, y: 0, width: 320, height: 500)
        notice.layoutIfNeeded()
        let size = notice.systemLayoutSizeFitting(CGSize(width: 320, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        notice.frame.size = size
        notice.layoutIfNeeded()
        XCTAssertLessThan(size.height, 400)
        let items = descendants(notice).filter { $0 is UILabel || $0 is UIButton }
        for item in items {
            let rect = item.convert(item.bounds, to: notice)
            XCTAssertGreaterThanOrEqual(rect.minX, -1)
            XCTAssertLessThanOrEqual(rect.maxX, 321)
            XCTAssertLessThanOrEqual(rect.maxY, size.height + 1)
        }
        let label = items.compactMap { $0 as? UILabel }.first { $0.accessibilityIdentifier == "ad_removal_notice_message" }!
        let learn = items.first { $0.accessibilityIdentifier == "ad_removal_notice_learn_more" }!
        XCTAssertFalse(label.convert(label.bounds, to: notice).intersects(learn.convert(learn.bounds, to: notice)))
    }

    func testRootLearnMoreConsumesNoticeAndPushesExistingPurchaseScreenOnlyOnce() {
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        let model = makeViewModel()
        let root = makeRoot(model: model)
        let navigation = UINavigationController(rootViewController: root)
        root.loadViewIfNeeded()
        let learn = descendants(root.adRemovalNoticeView).first {
            $0.accessibilityIdentifier == "ad_removal_notice_learn_more"
        } as! UIButton
        learn.sendActions(for: .touchUpInside)
        XCTAssertTrue(navigation.topViewController is PurchaseNoticeViewController)
        XCTAssertFalse(model.isEligible)
        XCTAssertTrue(root.adRemovalNoticeView.isHidden)
        XCTAssertFalse(makeViewModel().isEligible)
        learn.sendActions(for: .touchUpInside)
        XCTAssertEqual(navigation.viewControllers.count, 2)
        navigation.popViewController(animated: false)
        XCTAssertTrue(root.adRemovalNoticeView.isHidden)
    }

    func testRootCloseConsumesWithoutNavigationAndPurchaseChangeHidesNotice() {
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        let model = makeViewModel()
        let root = makeRoot(model: model)
        let navigation = UINavigationController(rootViewController: root)
        root.loadViewIfNeeded()
        XCTAssertFalse(root.adRemovalNoticeView.isHidden)
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .adFree))
        XCTAssertTrue(root.adRemovalNoticeView.isHidden)
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        let close = descendants(root.adRemovalNoticeView).first {
            $0.accessibilityIdentifier == "ad_removal_notice_close"
        } as! UIButton
        close.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.adRemovalNoticeView.isHidden)
        XCTAssertFalse(makeViewModel().isEligible)
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    func testRealNoticeAndBannerFitSmallScreenInBothThemesAndCloseWithoutRemovingBanner() async {
        purchases.subject.send(AdRemovalPurchaseState(entitlement: .notPurchased))
        for (style, category): (UIUserInterfaceStyle, UIContentSizeCategory) in [
            (.light, .large), (.dark, .accessibilityExtraExtraExtraLarge)
        ] {
            defaults.removePersistentDomain(forName: suite)
            OnboardingManager.markAsShown(defaults: defaults)
            let root = makeRoot(model: makeViewModel())
            root.overrideUserInterfaceStyle = style
            root.traitOverrides.preferredContentSizeCategory = category
            var requested: BannerView?
            let host = BannerAdHost(service: NoticeBannerService(), placement: .characterList,
                analytics: NoOpAnalyticsClient(), accessoryView: root.adRemovalNoticeView,
                loadAd: { requested = $0 }, isApplicationActive: { true })
            root.bannerAdHost = host
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            window.rootViewController = root
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            await Task.yield()
            root.view.layoutIfNeeded()
            host.appear()
            guard let banner = requested else { XCTFail("Expected banner request"); return }
            host.bannerViewDidReceiveAd(banner)
            root.view.layoutIfNeeded()
            root.view.setNeedsLayout()
            root.view.layoutIfNeeded()
            let notice = root.adRemovalNoticeView
            let noticeFrame = notice.convert(notice.bounds, to: root.view)
            let bannerFrame = banner.convert(banner.bounds, to: root.view)
            let collection = descendants(root.view).compactMap { $0 as? UICollectionView }.first!
            let contentFrame = collection.convert(collection.bounds, to: root.view)
            XCTAssertGreaterThan(contentFrame.height, 100)
            XCTAssertEqual(contentFrame.maxY, noticeFrame.minY, accuracy: 1)
            XCTAssertEqual(noticeFrame.maxY, bannerFrame.minY, accuracy: 1)
            XCTAssertLessThanOrEqual(bannerFrame.maxY, root.view.bounds.maxY)
            XCTAssertFalse(notice.isHidden)
            let message = descendants(notice).first { $0.accessibilityIdentifier == "ad_removal_notice_message" } as! UILabel
            if category.isAccessibilityCategory {
                XCTAssertGreaterThan(message.font.pointSize, 30, "The snapshot must exercise actual large text")
            }
            let image = UIGraphicsImageRenderer(bounds: root.view.bounds).image { _ in
                root.view.drawHierarchy(in: root.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "ad-removal-notice-\(style.rawValue)-\(category.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let close = descendants(notice).first { $0.accessibilityIdentifier == "ad_removal_notice_close" } as! UIButton
            close.sendActions(for: .touchUpInside)
            notice.superview?.layoutIfNeeded()
            root.view.setNeedsLayout()
            root.view.layoutIfNeeded()
            let expanded = collection.convert(collection.bounds, to: root.view)
            XCTAssertEqual(expanded.height - contentFrame.height, noticeFrame.height, accuracy: 1)
            XCTAssertNotNil(banner.superview)
            host.disappear()
        }
    }

    private func makeRoot(model: AdRemovalNoticeViewModel) -> CharacterListViewController {
        CharacterListViewController(characterListViewModel: NoticeCharacters(),
            container: DIContainer(analytics: NoOpAnalyticsClient()),
            preference: CharacterLayoutPreference(manager: UserDefaultsManager(store: defaults)),
            analytics: NoOpAnalyticsClient(), onboardingDefaults: defaults, adRemovalNoticeViewModel: model)
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}

@MainActor
private final class NoticePurchases: AdRemovalPurchasing {
    let subject = CurrentValueSubject<AdRemovalPurchaseState, Never>(AdRemovalPurchaseState())
    var state: AdRemovalPurchaseState { subject.value }
    var statePublisher: AnyPublisher<AdRemovalPurchaseState, Never> { subject.eraseToAnyPublisher() }
    func refresh() async {}
    func loadProduct() async {}
    func purchase() async -> AdRemovalActionResult { .cancelled }
    func restore() async -> AdRemovalActionResult { .noPurchases }
}

@MainActor
private final class NoticeCharacters: CharacterFetchable, CharacterSelectable {
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

@MainActor
private final class NoticeBannerService: BannerAdServing {
    let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
        appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { Just((true, true)).eraseToAnyPublisher() }
    func prepare(from controller: UIViewController) async -> AdPreparationResult { .ready }
}
