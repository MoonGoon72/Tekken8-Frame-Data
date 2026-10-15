import Combine
import GoogleMobileAds
import UIKit
import XCTest
@testable import TK8

@MainActor
final class NativeAdHostTests: XCTestCase {
    private var service: FooterAdService!
    private var controller: UIViewController!
    private var content: UIView!
    private var host: NativeAdHost!
    private var analytics: RecordingAnalyticsClient!
    private var requests: [AdLoader] = []

    override func setUp() async throws {
        service = FooterAdService()
        controller = UIViewController()
        content = controller.view
        analytics = RecordingAnalyticsClient()
        host = NativeAdHost(service: service, placement: .memoList, analytics: analytics,
                            loadAd: { [weak self] in self?.requests.append($0) }, isApplicationActive: { true })
        host.install(in: controller)
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        controller.view.layoutIfNeeded()
    }

    override func tearDown() async throws {
        host.disappear()
        host = nil
        controller = nil
        content = nil
        service = nil
        analytics = nil
        requests = []
    }

    func testFailedRequestCollapsesWithoutRetryAndIgnoresLateSuccess() {
        host.appear()
        let request = requests[0]
        host.adLoader(request, didFailToReceiveAdWithError: NSError(domain: "test", code: 2))
        host.adLoader(request, didReceive: NativeAd())
        host.layout()
        controller.view.layoutIfNeeded()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(content.frame.height, 568)
        XCTAssertEqual(analytics.events, [.nativeAdLoadFailed(placement: .memoList, code: 2)])
    }

    func testPurchaseAndLeavingScreenRejectLateCallbacks() {
        host.appear()
        let request = requests[0]
        service.state.send((false, true))
        host.adLoader(request, didReceive: NativeAd())
        host.adLoader(request, didFailToReceiveAdWithError: NSError(domain: "test", code: 2))
        XCTAssertTrue(analytics.events.isEmpty)
        service.state.send((true, true))
        XCTAssertEqual(requests.count, 2)
        host.disappear()
        host.adLoader(requests[1], didReceive: NativeAd())
        controller.view.layoutIfNeeded()
        XCTAssertEqual(content.frame.height, 568)
    }

    func testImpressionOnlyComesFromSDKOnceAndEditingRemovesAd() {
        host.appear()
        let ad = NativeAd()
        host.adLoader(requests[0], didReceive: ad)
        controller.view.layoutIfNeeded()
        XCTAssertLessThan(content.frame.height, 568)
        XCTAssertTrue(analytics.events.isEmpty)
        host.nativeAdDidRecordImpression(ad)
        host.nativeAdDidRecordImpression(ad)
        XCTAssertEqual(analytics.events, [.nativeAdImpression(placement: .memoList)])
        host.setEditing(true)
        host.nativeAdDidRecordImpression(ad)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(content.frame.height, 568)
        host.setEditing(false)
        XCTAssertEqual(requests.count, 2)
    }

    func testKeyboardSuppressesRequestUntilHidden() {
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.appear()
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 300, width: 320, height: 268)])
        host.layout()
        XCTAssertEqual(requests.count, 1)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        XCTAssertEqual(requests.count, 2)
    }

    func testFooterEventContractSupportsEveryPlacement() {
        for placement in BannerPlacement.allCases {
            XCTAssertEqual(TK8AnalyticsEvent.nativeAdImpression(placement: placement).parameters["ad_placement"], .string(placement.rawValue))
            XCTAssertEqual(TK8AnalyticsEvent.nativeAdLoadFailed(placement: placement, code: 3).parameters["ad_error_code"], .integer(3))
        }
    }

    func testVideoRetainsMinimumMediaSizeOnSmallPhone() {
        let view = CompactNativeAdView()
        view.configure(with: FooterVideoAd())
        let height = view.requiredHeight(for: 296)
        view.frame = CGRect(x: 0, y: 0, width: 296, height: height)
        view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(view.mediaView!.bounds.width, 120)
        XCTAssertGreaterThanOrEqual(view.mediaView!.bounds.height, 120)
        XCTAssertLessThanOrEqual(view.mediaView!.convert(view.mediaView!.bounds, to: view).maxY, height)
        attach(view, name: "Native footer video — small phone")
    }

    func testAccessibilityTextExpandsFooter() {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        child.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let view = CompactNativeAdView()
        child.view.addSubview(view)
        view.configure(with: NativeAd())
        (view.headlineView as? UILabel)?.text = "A readable advertisement title with larger text"
        let height = view.requiredHeight(for: 296)
        view.frame = CGRect(x: 0, y: 0, width: 296, height: height)
        view.layoutIfNeeded()
        XCTAssertGreaterThan(height, 80)
        let headline = view.headlineView as! UILabel
        XCTAssertLessThanOrEqual(headline.bounds.width, 276)
        XCTAssertGreaterThanOrEqual(headline.bounds.height + 1, headline.sizeThatFits(CGSize(width: headline.bounds.width, height: 10000)).height)
    }

    func testLongTitleFitsSmallWidthAndDarkAppearance() {
        let view = CompactNativeAdView()
        view.configure(with: FooterImageAd())
        (view.headlineView as? UILabel)?.text = "A long advertiser title that needs multiple lines on a small phone"
        view.overrideUserInterfaceStyle = .dark
        let height = view.requiredHeight(for: 296)
        view.frame = CGRect(x: 0, y: 0, width: 296, height: height)
        view.layoutIfNeeded()
        let headline = view.headlineView as! UILabel
        XCTAssertGreaterThanOrEqual(height, 68)
        XCTAssertEqual(headline.numberOfLines, 0)
        XCTAssertLessThanOrEqual(headline.convert(headline.bounds, to: view).maxY, height)
        attach(view, name: "Native footer image — small phone dark")
    }
    private func attach(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class FooterAdService: BannerAdServing {
    let state = CurrentValueSubject<(Bool, Bool), Never>((true, true))
    let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
        appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { state.eraseToAnyPublisher() }
    func prepare(from controller: UIViewController) async -> Bool { true }
}

@MainActor
private final class FooterVideoContent: MediaContent {
    override var hasVideoContent: Bool { true }
}

@MainActor
private final class FooterVideoAd: NativeAd {
    private let content = FooterVideoContent()
    override var mediaContent: MediaContent { content }
    override var headline: String? { "Example advertiser title" }
    override var callToAction: String? { "Visit site" }
}

@MainActor
private final class FooterIcon: NativeAdImage {
    override var image: UIImage? { UIImage(systemName: "gamecontroller.fill") }
}

@MainActor
private final class FooterImageAd: NativeAd {
    private let adIcon = FooterIcon()
    override var icon: NativeAdImage? { adIcon }
    override var headline: String? { "Example advertiser title" }
    override var callToAction: String? { "Visit site" }
}
