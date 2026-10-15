import Combine
import GoogleMobileAds
import UIKit
import XCTest
@testable import TK8

@MainActor
final class NativePurchaseAdTests: XCTestCase {
    func testRightsResolvedStartsPreparationBeforeConsentIsKnown() async {
        let service = NativePurchaseBannerStub()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let requested = expectation(description: "native request after rights and consent")
        let loader = NativeMoveAdLoader(service: service, analytics: NoOpAnalyticsClient(), loadAd: { _ in requested.fulfill() })
        loader.load(placements: [4], from: controller)
        // The first preparation sees unresolved rights and does not authorize ads.
        while service.prepareCount == 0 { await Task.yield() }
        await Task.yield()
        service.state.send((true, false))
        await fulfillment(of: [requested], timeout: 2)
        loader.reset()
    }

    func testRefundCanResumeWhileOldPreparationIsStillWaiting() async {
        let service = NativePurchaseBannerStub()
        service.state.send((true, true))
        service.suspendFirstPreparation = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        var requestCount = 0
        let requested = expectation(description: "new generation resumes after refund")
        let loader = NativeMoveAdLoader(service: service, analytics: NoOpAnalyticsClient(), loadAd: { _ in
            requestCount += 1
            if requestCount == 1 { requested.fulfill() }
        })
        loader.load(placements: [4], from: controller)
        while service.gate == nil { await Task.yield() }
        service.state.send((false, true)) // Purchase destroys pending work.
        service.state.send((true, true)) // Refund permits a new generation.
        await fulfillment(of: [requested], timeout: 2)
        service.gate?.resume(returning: true)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(requestCount, 1, "The old task must not request a duplicate native ad")
        loader.reset()
    }
}

@MainActor
private final class NativePurchaseBannerStub: BannerAdServing {
    let state = CurrentValueSubject<(Bool, Bool), Never>((false, false))
    let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
        appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { state.eraseToAnyPublisher() }
    var prepareCount = 0
    var suspendFirstPreparation = false
    var gate: CheckedContinuation<Bool, Never>?
    func prepare(from controller: UIViewController) async -> Bool {
        prepareCount += 1
        if suspendFirstPreparation && prepareCount == 1 {
            return await withCheckedContinuation { gate = $0 }
        }
        guard state.value.0 else { return false }
        if !state.value.1 { state.send((true, true)) }
        return true
    }
}
