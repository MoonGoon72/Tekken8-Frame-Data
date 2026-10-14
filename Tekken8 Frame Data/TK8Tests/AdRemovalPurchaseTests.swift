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

    func testRestoreMessageWaitsForSettingsToReturn() async {
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        let settings = SettingViewController(analytics: NoOpAnalyticsClient(), purchaseViewModel: viewModel)
        let navigation = UINavigationController(rootViewController: settings)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.view.frame = window.bounds
        navigation.view.layoutIfNeeded()
        navigation.beginAppearanceTransition(true, animated: false)
        navigation.endAppearanceTransition()
        defer { window.isHidden = true }
        await settlePurchaseMessageUI()
        XCTAssertNotNil(settings.viewIfLoaded?.window, "Settings must be attached to the test window")
        navigation.pushViewController(UIViewController(), animated: false)
        await viewModel.restore()
        await settlePurchaseMessageUI()
        let pending = viewModel.message
        XCTAssertNotNil(pending)
        XCTAssertNil(settings.presentedViewController)
        navigation.popViewController(animated: false)
        await settlePurchaseMessageUI()
        XCTAssertNotNil(settings.viewIfLoaded?.window, "Returning settings must be visible")
        XCTAssertTrue(navigation.topViewController === settings)
        // Explicitly deliver appearance for the detached test-window fixture.
        settings.viewDidAppear(false)
        XCTAssertEqual((settings.presentedViewController as? UIAlertController)?.message, pending)
        XCTAssertNil(viewModel.message)
        settings.dismiss(animated: false)
    }

    func testQueuedSubscribersIgnoreMessageConsumedByAnotherScreen() async {
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        let settings = SettingViewController(analytics: NoOpAnalyticsClient(), purchaseViewModel: viewModel)
        let navigation = UINavigationController(rootViewController: settings)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.view.frame = window.bounds
        navigation.view.layoutIfNeeded()
        navigation.beginAppearanceTransition(true, animated: false)
        navigation.endAppearanceTransition()
        defer { window.isHidden = true }
        await settlePurchaseMessageUI()
        XCTAssertNotNil(settings.viewIfLoaded?.window, "Settings must be attached to the test window")
        let notice = PurchaseNoticeViewController(viewModel: viewModel) { _ in }
        navigation.pushViewController(notice, animated: false)
        navigation.view.layoutIfNeeded()
        XCTAssertNotNil(notice.viewIfLoaded?.window)
        await viewModel.restore()
        let pending = viewModel.message
        XCTAssertNotNil(pending)
        // Simulate another presenter consuming the result before queued callbacks run.
        viewModel.clearMessage()
        await settlePurchaseMessageUI()
        XCTAssertNil(settings.presentedViewController)
        XCTAssertNil(notice.presentedViewController, "Queued blocks must re-read the consumed message")
    }

    func testVisiblePurchaseNoticeConsumesSharedMessageOnlyOnce() async {
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        let settings = SettingViewController(analytics: NoOpAnalyticsClient(), purchaseViewModel: viewModel)
        let navigation = UINavigationController(rootViewController: settings)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.view.frame = window.bounds
        navigation.view.layoutIfNeeded()
        navigation.beginAppearanceTransition(true, animated: false)
        navigation.endAppearanceTransition()
        defer { window.isHidden = true }
        await settlePurchaseMessageUI()
        XCTAssertNotNil(settings.viewIfLoaded?.window, "Settings must be attached to the test window")
        let notice = PurchaseNoticeViewController(viewModel: viewModel) { _ in }
        navigation.pushViewController(notice, animated: false)
        navigation.view.layoutIfNeeded()
        XCTAssertNotNil(notice.viewIfLoaded?.window)
        await viewModel.restore()
        await settlePurchaseMessageUI()
        XCTAssertNotNil(notice.presentedViewController as? UIAlertController)
        XCTAssertNil(viewModel.message)
        notice.dismiss(animated: false)
        await settlePurchaseMessageUI()
        navigation.popViewController(animated: false)
        await settlePurchaseMessageUI()
        XCTAssertNil(settings.presentedViewController)
    }

    private func settlePurchaseMessageUI() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { continuation.resume() }
        }
    }

    func testSettingsPurchaseRowsFitSmallScreenAndAccessibilityTextInBothThemes() async {
        for style in [UIUserInterfaceStyle.light, .dark] {
          for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            let viewModel = SettingsPurchaseViewModel(purchases: service)
            await viewModel.prepare()
            let controller = SettingViewController(analytics: NoOpAnalyticsClient(), purchaseViewModel: viewModel)
            controller.traitOverrides.userInterfaceStyle = style
            controller.traitOverrides.preferredContentSizeCategory = category
            let parent = UIViewController()
            parent.addChild(controller)
            parent.view.addSubview(controller.view)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
                controller.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
                controller.view.widthAnchor.constraint(equalToConstant: 320),
                controller.view.heightAnchor.constraint(equalToConstant: 568)
            ])
            controller.didMove(toParent: parent)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            window.rootViewController = parent
            window.makeKeyAndVisible()
            for _ in 0..<10 { await Task.yield() }
            parent.view.layoutIfNeeded()
            let table = (controller.view as! SettingTableView).tableView
            table.reloadData()
            table.layoutIfNeeded()
            XCTAssertEqual(table.numberOfRows(inSection: 0), 7)
            XCTAssertTrue(table.isScrollEnabled)
            if category.isAccessibilityCategory {
                XCTAssertGreaterThan(table.contentSize.height, table.bounds.height)
                table.scrollToRow(at: IndexPath(row: 2, section: 0), at: .top, animated: false)
                table.layoutIfNeeded()
            }
            let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0))
            let content = cell.contentConfiguration as! UIListContentConfiguration
            XCTAssertTrue(content.secondaryText?.contains("$2.99") == true)
            XCTAssertEqual(content.textProperties.numberOfLines, 0)
            XCTAssertEqual(content.secondaryTextProperties.numberOfLines, 0)
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "AdRemoval-320-\(category.rawValue)-\(style.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
          }
        }
    }

    private func prepare() async {
        await service.refresh()
        await service.loadProduct()
    }

    func testPurchaseNoticeRequiresExplicitBuyAndScrollsOnSmallScreens() async {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            for style in [UIUserInterfaceStyle.dark, .light] {
                let viewModel = SettingsPurchaseViewModel(purchases: service)
                await viewModel.prepare()
                let controller = PurchaseNoticeViewController(viewModel: viewModel, contact: { _ in })
                let parent = UIViewController()
                parent.addChild(controller)
                parent.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
                    UITraitCollection(preferredContentSizeCategory: category),
                    UITraitCollection(userInterfaceStyle: style)
                ]), forChild: controller)
                parent.view.addSubview(controller.view)
                controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                controller.didMove(toParent: parent)
                let window = UIWindow(frame: controller.view.frame)
                window.rootViewController = parent
                window.makeKeyAndVisible()
                for _ in 0..<10 { await Task.yield() }
                controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.view.bounds.size, CGSize(width: 320, height: 568))
                let scroll = controller.view.subviews.compactMap { $0 as? UIScrollView }.first!
                XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
                XCTAssertEqual(scroll.contentSize.width, scroll.bounds.width, accuracy: 1)
                XCTAssertEqual(store.purchaseCount, 0, "Opening purchase information must not start a purchase")
                for bottom in [false, true] {
                    scroll.contentOffset.y = bottom ? max(0, scroll.contentSize.height - scroll.bounds.height) : 0
                    let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                    }
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "PurchaseNotice-320-\(category.rawValue)-\(style.rawValue)-\(bottom ? "bottom" : "top")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                window.isHidden = true
            }
        }
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
