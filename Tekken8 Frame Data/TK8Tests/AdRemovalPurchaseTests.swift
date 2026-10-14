import Combine
import StoreKitTest
import UIKit
import XCTest
@testable import TK8

@MainActor
final class AdRemovalPurchaseTests: XCTestCase {
    private var store: StubAdRemovalStore!
    private var service: AdRemovalPurchaseService!

    override func setUp() async throws {
        store = StubAdRemovalStore()
        service = AdRemovalPurchaseService(store: store, startsAutomatically: false)
    }

    override func tearDown() async throws {
        service = nil
        store = nil
    }

    func testInitialUnknownAndNormalAbsenceHaveDifferentAdPolicies() async {
        XCTAssertFalse(service.state.entitlement.allowsAds)
        store.entitlement = .unknown
        await service.refresh()
        XCTAssertEqual(service.state.entitlement, .unknown)
        XCTAssertFalse(service.state.entitlement.allowsAds)
        store.entitlement = .notPurchased
        await service.refresh()
        XCTAssertTrue(service.state.entitlement.allowsAds)
        XCTAssertEqual(store.syncCount, 0, "Startup must not force App Store authentication")
    }

    func testVerifiedPurchaseDeliversRightsBeforeFinishing() async {
        await prepare()
        store.onFinish = { [weak service] in
            XCTAssertEqual(service?.state.entitlement, .adFree)
        }
        let result = await service.purchase()
        XCTAssertEqual(result, .purchased)
        XCTAssertEqual(store.finished, [1])
        XCTAssertFalse(service.state.entitlement.allowsAds)
    }

    func testCancellationAndPendingDoNotGrantRightsOrFinish() async {
        await prepare()
        store.result = .cancelled
        let cancelled = await service.purchase()
        XCTAssertEqual(cancelled, .cancelled)
        XCTAssertEqual(service.state.entitlement, .notPurchased)
        store.result = .pending
        let pending = await service.purchase()
        XCTAssertEqual(pending, .pending)
        XCTAssertTrue(service.state.pending)
        let duplicate = await service.purchase()
        XCTAssertEqual(duplicate, .busy)
        XCTAssertTrue(store.finished.isEmpty)
    }

    func testUnverifiedPurchaseSuppressesAdsWithoutClaimingSuccess() async {
        await prepare()
        store.purchaseError = AdRemovalPurchaseError.unverified
        let result = await service.purchase()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(service.state.entitlement, .unknown)
        XCTAssertTrue(store.finished.isEmpty)
    }

    func testRestoreDistinguishesNoPurchaseFromFailureAndPreservesVerifiedRights() async {
        let missing = await service.restore()
        XCTAssertEqual(missing, .noPurchases)
        store.entitlement = .adFree
        let restored = await service.restore()
        XCTAssertEqual(restored, .restored)
        store.syncError = AdRemovalPurchaseError.unavailable
        let failed = await service.restore()
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(service.state.entitlement, .adFree)
    }

    func testRefundUpdateReconcilesSnapshotAndFinishes() async {
        store.entitlement = .adFree
        service.start()
        await service.refresh()
        let finished = expectation(description: "refund reconciled")
        store.onFinish = { [weak service] in
            XCTAssertEqual(service?.state.entitlement, .notPurchased)
            finished.fulfill()
        }
        store.entitlement = .notPurchased
        store.continuation.yield(.verified(AdRemovalTransaction(id: 1, productID: "remove_ad", revoked: true)))
        await fulfillment(of: [finished], timeout: 2)
    }

    func testOldRefundDoesNotRemoveNewPurchase() async {
        store.entitlement = .adFree
        service.start()
        let finished = expectation(description: "old refund processed")
        store.onFinish = { [weak service] in
            XCTAssertEqual(service?.state.entitlement, .adFree)
            finished.fulfill()
        }
        store.continuation.yield(.verified(AdRemovalTransaction(id: 1, productID: "remove_ad", revoked: true)))
        await fulfillment(of: [finished], timeout: 2)
    }

    func testDuplicatePurchaseDoesNotOpenAnotherPayment() async {
        await prepare()
        store.purchaseGate = true
        let first = Task { await service.purchase() }
        while store.purchaseContinuation == nil { await Task.yield() }
        let duplicate = await service.purchase()
        XCTAssertEqual(duplicate, .busy)
        store.purchaseContinuation?.resume(returning: .cancelled)
        _ = await first.value
        XCTAssertEqual(store.purchaseCount, 1)
    }

    func testStaleStartupSnapshotCannotOverwriteNewPurchase() async {
        await prepare()
        store.entitlementGate = true
        let refresh = Task { await service.refresh() }
        while store.entitlementContinuation == nil { await Task.yield() }
        let result = await service.purchase()
        XCTAssertEqual(result, .purchased)
        store.entitlementContinuation?.resume(returning: .notPurchased)
        await refresh.value
        XCTAssertEqual(service.state.entitlement, .adFree)
    }

    func testProductUnavailableAndUnknownRightsPreventCheckout() async {
        store.productError = AdRemovalPurchaseError.unavailable
        await service.refresh()
        await service.loadProduct()
        let result = await service.purchase()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(store.purchaseCount, 0)
        store.productError = nil
        store.entitlement = .unknown
        await service.refresh()
        await service.loadProduct()
        let unknown = await service.purchase()
        XCTAssertEqual(unknown, .failed)
        XCTAssertEqual(store.purchaseCount, 0)
    }

    func testAdvertisingNeverBypassesPurchaseRightsOnRemoteOrConsentChanges() async {
        let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
            appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
        let ads = BannerAdService(configuration: configuration, purchases: service)
        var enabled = true
        let subscription = ads.statePublisher.sink { enabled = $0.0 }
        XCTAssertFalse(enabled)
        await prepare()
        XCTAssertTrue(enabled)
        _ = await service.purchase()
        XCTAssertFalse(enabled)
        await ads.refresh()
        XCTAssertFalse(enabled)
        let canRequest = await ads.prepare(from: UIViewController())
        XCTAssertFalse(canRequest)
        withExtendedLifetime(subscription) {}
    }

    func testViewModelSilentlyHandlesCancellationAndUsesStorePrice() async {
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        await viewModel.prepare()
        XCTAssertTrue(viewModel.canPurchase)
        XCTAssertEqual(viewModel.purchaseDetail, "$2.99")
        store.result = .cancelled
        await viewModel.buy()
        XCTAssertNil(viewModel.message)
        store.result = .pending
        await viewModel.buy()
        XCTAssertNotNil(viewModel.message)
        XCTAssertFalse(viewModel.canPurchase)
    }


    private func prepare() async {
        await service.refresh()
        await service.loadProduct()
    }

}

@MainActor
private final class StubAdRemovalStore: AdRemovalStore {
    var entitlement: AdRemovalEntitlement = .notPurchased
    var result: AdRemovalPurchaseResult = .success(AdRemovalTransaction(id: 1, productID: "remove_ad", revoked: false))
    var purchaseError: Error?
    var syncError: Error?
    var productError: Error?
    var finished: [UInt64] = []
    var syncCount = 0
    var purchaseCount = 0
    var onFinish: (() -> Void)?
    var purchaseGate = false
    var entitlementGate = false
    var purchaseContinuation: CheckedContinuation<AdRemovalPurchaseResult, Never>?
    var entitlementContinuation: CheckedContinuation<AdRemovalEntitlement, Never>?
    var continuation: AsyncStream<AdRemovalTransactionUpdate>.Continuation!

    func loadDisplayPrice() async throws -> String {
        if let productError { throw productError }
        return "$2.99"
    }
    func currentEntitlement() async -> AdRemovalEntitlement {
        if entitlementGate { return await withCheckedContinuation { entitlementContinuation = $0 } }
        return entitlement
    }
    func purchase() async throws -> AdRemovalPurchaseResult {
        purchaseCount += 1
        if let purchaseError { throw purchaseError }
        if purchaseGate { return await withCheckedContinuation { purchaseContinuation = $0 } }
        return result
    }
    func sync() async throws {
        syncCount += 1
        if let syncError { throw syncError }
    }
    func updates() -> AsyncStream<AdRemovalTransactionUpdate> {
        AsyncStream { continuation = $0 }
    }
    func finish(_ transaction: AdRemovalTransaction) async {
        onFinish?()
        finished.append(transaction.id)
    }
}

@MainActor
final class AdRemovalStoreKitTests: XCTestCase {
    func testConfiguredProductPurchaseAndRefundWithoutServer() async throws {
        let session = try SKTestSession(configurationFileNamed: "AdRemoval")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let store = StoreKitAdRemovalStore()
        let price = try await store.loadDisplayPrice()
        XCTAssertFalse(price.isEmpty)
        let before = await store.currentEntitlement()
        XCTAssertEqual(before, .notPurchased)
        let transaction = try await session.buyProduct(identifier: "remove_ad")
        let purchased = await waitForEntitlement(.adFree, store: store)
        XCTAssertEqual(purchased, .adFree)
        try session.refundTransaction(identifier: UInt(transaction.id))
        let refunded = await waitForEntitlement(.notPurchased, store: store)
        XCTAssertEqual(refunded, .notPurchased)
    }

    private func waitForEntitlement(_ expected: AdRemovalEntitlement, store: StoreKitAdRemovalStore) async -> AdRemovalEntitlement {
        // SKTestSession injects transactions asynchronously into StoreKit's cache.
        // Wait for that boundary rather than assuming the cache is synchronous.
        for _ in 0..<100 {
            let state = await store.currentEntitlement()
            if state == expected { return state }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return await store.currentEntitlement()
    }
}
