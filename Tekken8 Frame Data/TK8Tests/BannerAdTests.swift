import Combine
import GoogleMobileAds
import UIKit
import XCTest
@testable import TK8

final class BannerAdConfigurationTests: XCTestCase {
    func testNativeMoveAdsUseTwentyMoveIntervalsAfterFourthMove() {
        XCTAssertEqual(MoveListViewController.nativeAdPlacements(moveCount: 3), [])
        XCTAssertEqual(MoveListViewController.nativeAdPlacements(moveCount: 4), [4])
        XCTAssertEqual(MoveListViewController.nativeAdPlacements(moveCount: 24), [4, 24])
        XCTAssertEqual(MoveListViewController.nativeAdPlacements(moveCount: 45), [4, 24, 44])
    }

    func testDebugNeverUsesProductionBannerID() {
        let configuration = makeConfiguration(debug: true, testing: false)
        XCTAssertEqual(configuration.adUnitID, BannerAdConfiguration.sampleBannerID)
        XCTAssertEqual(configuration.nativeAdUnitID, BannerAdConfiguration.sampleNativeID)
    }

    func testDebugWithRealAppIDStillUsesLocalTestAds() {
        let configuration = BannerAdConfiguration(
            isDebug: true,
            isTesting: false,
            appID: "ca-app-pub-1234567890123456~1234567890",
            bannerID: "ca-app-pub-1234567890123456/1234567890",
            nativeID: "ca-app-pub-1234567890123456/1234567890",
            localTestEnabled: true
        )

        XCTAssertTrue(configuration.usesLocalTestAds)
        XCTAssertEqual(configuration.adUnitID, BannerAdConfiguration.sampleBannerID)
        XCTAssertEqual(configuration.nativeAdUnitID, BannerAdConfiguration.sampleNativeID)
    }

    func testReleaseAndTestHostCannotUseLocalTestAds() {
        XCTAssertFalse(makeConfiguration(debug: false, testing: false).usesLocalTestAds)
        XCTAssertFalse(makeConfiguration(debug: true, testing: true).usesLocalTestAds)
    }

    func testTestHostNeverRequestsAds() {
        XCTAssertNil(makeConfiguration(debug: true, testing: true).adUnitID)
        XCTAssertNil(makeConfiguration(debug: false, testing: true).adUnitID)
    }

    func testReleaseRequiresRealAndWellFormedIDs() {
        let releaseConfiguration = makeConfiguration(debug: false, testing: false)
        XCTAssertNotNil(releaseConfiguration.adUnitID)
        XCTAssertTrue(releaseConfiguration.usesNativeMoveAds)
        for id in ["", "$(ADMOB_APP_ID)", BannerAdConfiguration.sampleAppID, "ca-app-pub-invalid"] {
            let configuration = BannerAdConfiguration(isDebug: false, isTesting: false, appID: id,
                bannerID: "ca-app-pub-1234567890123456/1234567890", nativeID: "ca-app-pub-1234567890123456/1234567890", localTestEnabled: false)
            XCTAssertNil(configuration.adUnitID)
        }
        let sample = BannerAdConfiguration(isDebug: false, isTesting: false,
            appID: "ca-app-pub-1234567890123456~1234567890",
            bannerID: BannerAdConfiguration.sampleBannerID, nativeID: BannerAdConfiguration.sampleNativeID, localTestEnabled: true)
        XCTAssertNil(sample.adUnitID)
        XCTAssertFalse(sample.usesNativeMoveAds)
    }

    func testEverySuppressionConditionPreventsLoading() {
        let allowed = BannerAdPolicy(enabled: true, visible: true, consentAllowsAds: true)
        XCTAssertTrue(allowed.canLoad)
        var policy = allowed
        policy.enabled = false
        XCTAssertFalse(policy.canLoad)
        policy = allowed; policy.visible = false
        XCTAssertFalse(policy.canLoad)
        policy = allowed; policy.keyboardVisible = true
        XCTAssertFalse(policy.canLoad)
        policy = allowed; policy.editing = true
        XCTAssertFalse(policy.canLoad)
        policy = allowed; policy.consentAllowsAds = false
        XCTAssertFalse(policy.canLoad)
    }

    func testAdEventContractContainsOnlyPlacementAndNumericFailure() {
        XCTAssertEqual(TK8AnalyticsEvent.bannerImpression(placement: .moveList),
                       TK8AnalyticsEvent(name: "banner_ad_impression", parameters: [
                        "ad_placement": .string("move_list"), "ad_format": .string("banner")]))
        XCTAssertEqual(TK8AnalyticsEvent.bannerLoadFailed(placement: .memoList, code: 2),
                       TK8AnalyticsEvent(name: "banner_ad_load_failed", parameters: [
                        "ad_placement": .string("memo_list"), "ad_error_code": .integer(2)]))
    }

    func testNativeAdEventContractContainsOnlyPlacementAndNumericFailure() {
        XCTAssertEqual(TK8AnalyticsEvent.nativeAdImpression(placement: .moveList),
                       TK8AnalyticsEvent(name: "native_ad_impression", parameters: [
                        "ad_placement": .string("move_list"), "ad_format": .string("native")]))
        XCTAssertEqual(TK8AnalyticsEvent.nativeAdLoadFailed(placement: .moveList, code: 2),
                       TK8AnalyticsEvent(name: "native_ad_load_failed", parameters: [
                        "ad_placement": .string("move_list"), "ad_error_code": .integer(2)]))
    }

    private func makeConfiguration(debug: Bool, testing: Bool) -> BannerAdConfiguration {
        BannerAdConfiguration(isDebug: debug, isTesting: testing,
            appID: "ca-app-pub-1234567890123456~1234567890",
            bannerID: "ca-app-pub-1234567890123456/1234567890", nativeID: "ca-app-pub-1234567890123456/1234567890", localTestEnabled: false)
    }
}

@MainActor
final class BannerAdHostTests: XCTestCase {
    private var service: StubBannerService!
    private var controller: UIViewController!
    private var content: UIView!
    private var host: BannerAdHost!
    private var analytics: RecordingAnalyticsClient!
    private var requests: [BannerView] = []

    override func setUp() async throws {
        service = StubBannerService()
        controller = UIViewController()
        content = controller.view
        analytics = RecordingAnalyticsClient()
        host = BannerAdHost(service: service, placement: .moveList, analytics: analytics,
                            loadAd: { [weak self] in self?.requests.append($0) },
                            isApplicationActive: { true })
        host.install(in: controller)
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        controller.view.layoutIfNeeded()
    }

    override func tearDown() async throws {
        host.disappear()
        host = nil
        controller = nil
        content = nil
        requests = []
        service = nil
        analytics = nil
    }

    func testRemoteOffCollapsesBannerAndIgnoresLateLoad() {
        host.appear()
        let banner = requests[0]
        host.bannerViewDidReceiveAd(banner)
        XCTAssertNotNil(banner.superview)

        service.state.send((false, true))
        host.bannerViewDidReceiveAd(banner)
        host.bannerViewDidRecordImpression(banner)
        XCTAssertNil(banner.superview)
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testEditingDestroysAdAndResumesWithNewRequest() {
        host.appear()
        let first = requests[0]
        host.setEditing(true)
        XCTAssertNil(first.superview)
        host.layout()
        XCTAssertEqual(requests.count, 1)
        host.setEditing(false)
        XCTAssertEqual(requests.count, 2)
        XCTAssertFalse(first === requests[1])
    }

    func testFailureHasNoBlankSpaceOrAutomaticRetryLoop() {
        host.appear()
        let banner = requests[0]
        host.bannerView(banner, didFailToReceiveAdWithError: NSError(domain: "test", code: 2))
        host.layout()
        controller.view.layoutIfNeeded()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(content.frame.height, controller.view.bounds.height)
        XCTAssertEqual(analytics.events, [.bannerLoadFailed(placement: .moveList, code: 2)])
    }

    func testLeavingScreenRejectsLateImpressionAndLoad() {
        host.appear()
        let banner = requests[0]
        host.disappear()
        host.bannerViewDidReceiveAd(banner)
        host.bannerViewDidRecordImpression(banner)
        XCTAssertNil(banner.superview)
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testOnlySDKImpressionRecordsExposureOncePerCreative() {
        host.appear()
        let banner = requests[0]
        host.bannerViewDidReceiveAd(banner)
        XCTAssertTrue(analytics.events.isEmpty)
        host.bannerViewDidRecordImpression(banner)
        host.bannerViewDidRecordImpression(banner)
        XCTAssertEqual(analytics.events.count, 1)
        host.bannerViewDidReceiveAd(banner) // SDK auto-refresh delivers another creative.
        host.bannerViewDidRecordImpression(banner)
        XCTAssertEqual(analytics.events.count, 2)
    }
}

@MainActor
private final class StubBannerService: BannerAdServing {
    let state = CurrentValueSubject<(Bool, Bool), Never>((true, true))
    let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
        appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { state.eraseToAnyPublisher() }
    func prepare(from controller: UIViewController) async -> Bool { true }
}
