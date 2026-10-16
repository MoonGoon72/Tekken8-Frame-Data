import AppTrackingTransparency
import XCTest
@testable import TK8

@MainActor
final class AdTrackingAuthorizationTests: XCTestCase {
    func testExistingDecisionsNeverRequestAgain() async {
        for status in [ATTrackingManager.AuthorizationStatus.authorized, .denied, .restricted] {
            var requests = 0
            let authorization = AdTrackingAuthorization(status: { status }, request: {
                requests += 1
                return .authorized
            })
            let result = await authorization.requestIfNeeded()
            XCTAssertEqual(result, status)
            XCTAssertEqual(requests, 0)
        }
    }

    func testDecisionIsReadFromSystemAcrossServiceRecreation() async {
        for decision in [ATTrackingManager.AuthorizationStatus.authorized, .denied] {
            var status = ATTrackingManager.AuthorizationStatus.notDetermined
            var requests = 0
            func makeAuthorization() -> AdTrackingAuthorization {
                AdTrackingAuthorization(status: { status }, request: {
                    requests += 1
                    status = decision
                    return decision
                }, isActive: { true })
            }
            _ = await makeAuthorization().requestIfNeeded()
            _ = await makeAuthorization().requestIfNeeded()
            XCTAssertEqual(status, decision)
            XCTAssertEqual(requests, 1)
        }
    }

    func testConcurrentPlacementsShareOnePermissionRequest() async {
        var requests = 0
        var completion: CheckedContinuation<ATTrackingManager.AuthorizationStatus, Never>?
        var status = ATTrackingManager.AuthorizationStatus.notDetermined
        var onStatusRead: (() -> Void)?
        let authorization = AdTrackingAuthorization(status: {
            onStatusRead?()
            return status
        }, request: {
            requests += 1
            return await withCheckedContinuation { completion = $0 }
        }, isActive: { true })
        let first = Task { await authorization.requestIfNeeded() }
        while completion == nil { await Task.yield() }
        let secondEntered = expectation(description: "second caller entered the pending request")
        onStatusRead = {
            onStatusRead = nil
            secondEntered.fulfill()
        }
        let second = Task { await authorization.requestIfNeeded() }
        await fulfillment(of: [secondEntered], timeout: 2)
        // Mirror iOS: the stored decision changes before the callback completes.
        // A late-scheduled second caller then reads the decision instead of creating
        // an unresumed continuation; an overlapping caller shares pending work.
        status = .denied
        completion?.resume(returning: .denied)
        let results = await [first.value, second.value]
        XCTAssertEqual(results, [.denied, .denied])
        XCTAssertEqual(requests, 1)
    }

    func testDoesNotRequestWhileAppIsInactive() async {
        var active = false
        var requests = 0
        let authorization = AdTrackingAuthorization(status: { .notDetermined }, request: {
            XCTAssertTrue(active)
            requests += 1
            return .denied
        }, isActive: { active })
        let task = Task { await authorization.requestIfNeeded() }
        await Task.yield()
        XCTAssertEqual(requests, 0)
        active = true
        let result = await task.value
        XCTAssertEqual(result, .denied)
        XCTAssertEqual(requests, 1)
    }

    func testUnavailablePresenterDoesNotConsumeThePermissionRequest() async {
        var status = ATTrackingManager.AuthorizationStatus.notDetermined
        var requests = 0
        let authorization = AdTrackingAuthorization(status: { status }, request: {
            requests += 1
            status = .denied
            return status
        }, isActive: { true })
        let deferred = await authorization.requestIfNeeded(when: { false })
        XCTAssertEqual(deferred, .notDetermined)
        XCTAssertEqual(requests, 0)
        let decision = await authorization.requestIfNeeded(when: { true })
        XCTAssertEqual(decision, .denied)
        XCTAssertEqual(requests, 1)
    }

    func testOnlyAuthorizedRequestsCanUsePersonalizedAds() {
        XCTAssertEqual(AdRequestFactory.nonPersonalizedParameters(for: .authorized), [:])
        for status in [ATTrackingManager.AuthorizationStatus.notDetermined, .denied, .restricted] {
            XCTAssertEqual(AdRequestFactory.nonPersonalizedParameters(for: status), ["npa": "1"])
        }
    }
}
