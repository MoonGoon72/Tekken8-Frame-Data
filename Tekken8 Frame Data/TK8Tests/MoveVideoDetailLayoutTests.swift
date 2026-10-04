@testable import TK8
import Combine
import GoogleMobileAds
import UIKit
import XCTest

@MainActor
final class MoveVideoDetailLayoutTests: XCTestCase {
    func test_smallScreenKeepsCloseFixedAndScrollsLongContentWithoutHorizontalOverflow() async {
        await verifyLayout(size: CGSize(width: 375, height: 667), category: .accessibilityExtraExtraExtraLarge, style: .dark)
    }

    func test_regularScreenPreservesVideoRatioAndSupportsLightAppearance() async {
        await verifyLayout(size: CGSize(width: 430, height: 932), category: .large, style: .light)
    }

    func test_smallScreenWithBannerKeepsCloseAndAdFixedWhileContentScrolls() async {
        await verifyLayout(size: CGSize(width: 375, height: 667), category: .accessibilityExtraExtraExtraLarge, style: .dark, withBanner: true)
    }

    func test_regularScreenWithBannerPreservesVideoRatioInLightAppearance() async {
        await verifyLayout(size: CGSize(width: 430, height: 932), category: .large, style: .light, withBanner: true)
    }

    func test_interactiveDismissalCancellationPreservesDetailAndCommittedDismissalCleansUp() async {
        await verifyTransition(reduceMotion: false)
    }

    func test_reduceMotionFadeSupportsCancelledAndCommittedDismissal() async {
        await verifyTransition(reduceMotion: true)
    }

    func test_backGestureRejectsVideoAreaVerticalScrollAndLeftwardMovement() {
        let detail = MoveVideoPlayerViewController(move: longMove, reference: MoveVideoReference(moveID: 1, objectKey: "fixture.mp4", revision: nil, playbackURL: nil), playbackURLProvider: LayoutDeferredURLProvider())
        detail.loadViewIfNeeded()
        let installed = detail.view.gestureRecognizers!.compactMap { $0 as? UIPanGestureRecognizer }.first!
        XCTAssertTrue(installed.delegate === detail)
        XCTAssertEqual(installed.maximumNumberOfTouches, 1)
        let touch = TestLocationTouch()
        touch.point = CGPoint(x: 4, y: 300)
        XCTAssertTrue(detail.gestureRecognizer(installed, shouldReceive: touch))
        touch.point = CGPoint(x: 160, y: 300)
        XCTAssertFalse(detail.gestureRecognizer(installed, shouldReceive: touch))
        let pan = TestEdgePan()
        pan.testVelocity = CGPoint(x: 250, y: 10)
        XCTAssertTrue(detail.gestureRecognizerShouldBegin(pan))
        pan.testVelocity = CGPoint(x: 10, y: 250)
        XCTAssertFalse(detail.gestureRecognizerShouldBegin(pan))
        pan.testVelocity = CGPoint(x: -250, y: 10)
        XCTAssertFalse(detail.gestureRecognizerShouldBegin(pan))
    }

    private func verifyTransition(reduceMotion: Bool) async {
        let parent = UIViewController()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        window.rootViewController = parent
        window.makeKeyAndVisible()
        let source = UIView(frame: CGRect(x: 16, y: 120, width: 343, height: 240))
        source.backgroundColor = .red
        parent.view.addSubview(source)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let originalFrame = source.frame
        let provider = LayoutDeferredURLProvider()
        let detail = MoveVideoPlayerViewController(move: longMove, reference: MoveVideoReference(moveID: 1, objectKey: "fixture.mp4", revision: nil, playbackURL: nil), playbackURLProvider: provider)
        let transition = MoveVideoCardTransition(sourceView: { source }, reduceMotion: { reduceMotion })
        detail.cardTransition = transition
        detail.transitioningDelegate = transition
        detail.modalPresentationStyle = .custom
        let closed = expectation(description: "Committed dismissal")
        var dismissalCount = 0
        transition.didDismiss = {
            dismissalCount += 1
            detail.didFinishDismissal()
            closed.fulfill()
        }
        let presented = expectation(description: "Presented from source cell")
        parent.present(detail, animated: true) { presented.fulfill() }
        if !reduceMotion {
            try? await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertEqual(detail.view.bounds.size, window.bounds.size)
            XCTAssertEqual(detail.view.transform, .identity)
            if let layer = detail.view.layer.presentation() {
                XCTAssertTrue(CATransform3DIsIdentity(layer.transform), "Detail content must never stretch during expansion")
            }
            let revealFrame = detail.view.mask?.layer.presentation()?.frame
            XCTAssertNotNil(revealFrame)
            if let revealFrame {
                XCTAssertGreaterThan(revealFrame.height, originalFrame.height)
                XCTAssertLessThan(revealFrame.height, window.bounds.height)
            }
        }
        await fulfillment(of: [presented], timeout: 3)
        XCTAssertTrue(parent.presentedViewController === detail)
        XCTAssertNotNil(parent.view.window)
        XCTAssertNotNil(provider.pending)
        XCTAssertNil(detail.view.mask)
        let originalState = detail.playback.state
        let cancelled = expectation(description: "Cancelled transition restored")
        let pan = TestEdgePan()
        pan.testState = .began
        transition.handle(pan, in: detail)
        detail.transitionCoordinator?.animate(alongsideTransition: nil) { context in
            XCTAssertTrue(context.isCancelled)
            cancelled.fulfill()
        }
        pan.testTranslation = CGPoint(x: detail.view.bounds.width * 0.1, y: 0)
        pan.testState = .changed
        transition.handle(pan, in: detail)
        pan.testState = .ended
        transition.handle(pan, in: detail)
        await fulfillment(of: [cancelled], timeout: 3)
        XCTAssertTrue(parent.presentedViewController === detail)
        XCTAssertEqual(detail.playback.state, originalState)
        XCTAssertEqual(dismissalCount, 0)
        XCTAssertEqual(detail.view.transform, .identity)
        XCTAssertNil(detail.view.mask)
        XCTAssertEqual(source.alpha, 1)
        pan.testTranslation = .zero
        pan.testState = .began
        transition.handle(pan, in: detail)
        pan.testTranslation = CGPoint(x: detail.view.bounds.width * 0.8, y: 0)
        pan.testState = .changed
        transition.handle(pan, in: detail)
        pan.testState = .ended
        transition.handle(pan, in: detail)
        await fulfillment(of: [closed], timeout: 3)
        XCTAssertNil(parent.presentedViewController)
        XCTAssertEqual(detail.playback.state, .stopped)
        XCTAssertEqual(dismissalCount, 1)
        XCTAssertEqual(source.frame, originalFrame)
        XCTAssertEqual(source.alpha, 1)
        provider.pending?.resume(throwing: URLError(.cancelled))
        transition.didDismiss = nil
        window.isHidden = true
    }

    private func verifyLayout(size: CGSize, category: UIContentSizeCategory, style: UIUserInterfaceStyle, withBanner: Bool = false) async {
        let provider = LayoutDeferredURLProvider()
        let detail = MoveVideoPlayerViewController(move: longMove, reference: MoveVideoReference(moveID: 1, objectKey: "fixture.mp4", revision: nil, playbackURL: nil), playbackURLProvider: provider)
        var banners: [BannerView] = []
        let analytics = RecordingAnalyticsClient()
        if withBanner {
            detail.bannerAdHost = BannerAdHost(service: DetailBannerService(), placement: .moveVideoDetail, analytics: analytics, contentSpacing: 12,
                                               loadAd: { banners.append($0) }, isApplicationActive: { true })
        }
        let parent = UIViewController()
        parent.view.frame = CGRect(origin: .zero, size: size)
        parent.addChild(detail)
        parent.view.addSubview(detail.view)
        detail.view.frame = parent.view.bounds
        parent.setOverrideTraitCollection(UITraitCollection(traitsFrom: [UITraitCollection(preferredContentSizeCategory: category), UITraitCollection(userInterfaceStyle: style)]), forChild: detail)
        detail.didMove(toParent: parent)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer {
            detail.didFinishDismissal()
            provider.pending?.resume(throwing: URLError(.cancelled))
            window.isHidden = true
        }
        // Wait for SwiftUI's intrinsic content size propagation into the UIKit stack.
        for _ in 0..<15 {
            parent.view.layoutIfNeeded()
            detail.view.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        var bannerPosition: CGRect?
        if withBanner {
            XCTAssertEqual(banners.count, 1)
            let banner = banners[0]
            detail.bannerAdHost!.bannerViewDidReceiveAd(banner)
            detail.view.layoutIfNeeded()
            bannerPosition = banner.convert(banner.bounds, to: detail.view)
        }
        let close = find("move_detail_close", in: detail.view)!
        let scroll = find("move_detail_scroll", in: detail.view) as! UIScrollView
        let video = find("move_detail_video", in: detail.view)!
        XCTAssertGreaterThanOrEqual(close.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(close.bounds.height, 44)
        XCTAssertFalse(scroll.isDescendant(of: close))
        XCTAssertFalse(close.isDescendant(of: scroll))
        XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        XCTAssertEqual(video.bounds.width, scroll.bounds.width - 32, accuracy: 1)
        XCTAssertEqual(video.bounds.width / video.bounds.height, 16 / 9, accuracy: 0.03)
        let position = close.convert(close.bounds, to: detail.view)
        scroll.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        detail.view.layoutIfNeeded()
        XCTAssertEqual(close.convert(close.bounds, to: detail.view), position)
        if let bannerPosition {
            let banner = banners[0]
            XCTAssertFalse(banner.isDescendant(of: scroll))
            XCTAssertEqual(banner.convert(banner.bounds, to: detail.view), bannerPosition)
            let scrollFrame = scroll.convert(scroll.bounds, to: detail.view)
            XCTAssertGreaterThanOrEqual(bannerPosition.minY - scrollFrame.maxY, 12)
            XCTAssertLessThanOrEqual(bannerPosition.maxY, detail.view.safeAreaLayoutGuide.layoutFrame.maxY + 1)
            detail.beginAppearanceTransition(false, animated: false)
            detail.endAppearanceTransition()
            detail.bannerAdHost!.bannerViewDidReceiveAd(banner)
            detail.bannerAdHost!.bannerViewDidRecordImpression(banner)
            XCTAssertNil(banner.superview)
            XCTAssertTrue(analytics.events.isEmpty)
            detail.beginAppearanceTransition(true, animated: false)
            detail.endAppearanceTransition() // Cancelled dismissal or return from a covering screen.
            XCTAssertEqual(banners.count, 2)
            detail.didFinishDismissal()
            detail.bannerAdHost!.bannerViewDidReceiveAd(banners[1])
            XCTAssertNil(banners[1].superview)
        }
        XCTAssertTrue(detail.view.accessibilityViewIsModal)
        XCTAssertNotNil(close.accessibilityLabel)
        // UIKit's hierarchy capture can temporarily move this fixture out of its
        // window and fire disappearance callbacks. Capture after lifecycle assertions.
        let renderer = UIGraphicsImageRenderer(bounds: detail.view.bounds)
        let image = renderer.image { _ in detail.view.drawHierarchy(in: detail.view.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Detail-\(category.rawValue)-\(style.rawValue)-banner-\(withBanner)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func find(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        return view.subviews.lazy.compactMap { self.find(id, in: $0) }.first
    }

    private var longMove: LocalizedMove {
        LocalizedMove(id: 1, sortOrder: 1, section: "일반", skillNamePrimary: "아주 긴 기술 이름 Very long move name for accessibility", skillNameSecondary: "Long secondary 기술명", command: "6rp,lp,rp,lp,rp,lp,rp,lp", commandEN: nil, judgment: "중,중,상,중,상", damage: "30(10+20)", startupFrame: "13~14F", guardFrame: "-12~-13", hitFrame: "+7~+8", counterFrame: "Launch", attribute: "powercrush", description: Array(repeating: "- 긴 기술 설명 Long move description | - 4 4 to cancel attack", count: 12).joined(separator: "| "))
    }
}

@MainActor
private final class DetailBannerService: BannerAdServing {
    let configuration = BannerAdConfiguration(isDebug: true, isTesting: false, appID: BannerAdConfiguration.sampleAppID,
                                             bannerID: "", nativeID: "", localTestEnabled: true)
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { Just((true, true)).eraseToAnyPublisher() }
    func prepare(from controller: UIViewController) async -> Bool { true }
}

@MainActor
private final class LayoutDeferredURLProvider: MoveVideoPlaybackURLProviding {
    var pending: CheckedContinuation<URL, Error>?
    func playbackURL(for reference: MoveVideoReference) async throws -> URL {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
}

@MainActor
private final class TestEdgePan: UIPanGestureRecognizer {
    var testState: UIGestureRecognizer.State = .possible
    var testTranslation = CGPoint.zero
    var testVelocity = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { testState }
        set { testState = newValue }
    }
    override func translation(in view: UIView?) -> CGPoint { testTranslation }
    override func velocity(in view: UIView?) -> CGPoint { testVelocity }
}

@MainActor
private final class TestLocationTouch: UITouch {
    var point = CGPoint.zero
    override func location(in view: UIView?) -> CGPoint { point }
}
