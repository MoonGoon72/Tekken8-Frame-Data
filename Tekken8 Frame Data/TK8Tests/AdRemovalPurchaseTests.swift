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

    func testInitialCheckSuppressesAdsButUnknownAndAbsenceAllowThem() async {
        XCTAssertFalse(service.state.entitlement.allowsAds)
        store.entitlement = .unknown
        await service.refresh()
        XCTAssertEqual(service.state.entitlement, .unknown)
        XCTAssertTrue(service.state.entitlement.allowsAds)
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

    func testUnverifiedPurchaseAllowsAdsWithoutClaimingSuccess() async {
        await prepare()
        store.verificationFailure = AdRemovalVerificationFailure(transactionID: 1, reason: .invalidSignature)
        store.purchaseError = AdRemovalPurchaseError.unverified
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        await viewModel.buy()
        XCTAssertEqual(service.state.entitlement, .unknown)
        XCTAssertEqual(service.state.verificationFailure?.reason, .invalidSignature)
        XCTAssertFalse(viewModel.canPurchase)
        XCTAssertTrue(service.state.entitlement.allowsAds)
        XCTAssertEqual(viewModel.message, "We could not verify your purchase. Do not buy again. Check purchases again, restore purchases, or contact the developer.".localized())
        let repeated = await service.purchase()
        XCTAssertEqual(repeated, .failed)
        XCTAssertEqual(store.purchaseCount, 1)
        XCTAssertTrue(store.finished.isEmpty)
    }

    func testUnverifiedUpdatePreservesVerifiedAdFreeEntitlement() async {
        store.entitlement = .adFree
        store.verificationFailure = AdRemovalVerificationFailure(transactionID: 2, reason: .invalidSignature)
        await service.refresh()
        service.start()
        while store.continuation == nil { await Task.yield() }

        store.continuation.yield(.unverified)
        for _ in 0..<100 where service.state.verificationFailure == nil { await Task.yield() }

        XCTAssertEqual(service.state.entitlement, .adFree)
        XCTAssertFalse(service.state.entitlement.allowsAds)
        XCTAssertEqual(service.state.verificationFailure?.transactionID, 2)
    }

    func testUnverifiedPurchaseFailurePreservesRightsFromConcurrentVerifiedUpdate() async {
        await prepare()
        store.purchaseGate = true
        service.start()
        let purchase = Task { await service.purchase() }
        while store.purchaseContinuation == nil || store.continuation == nil { await Task.yield() }

        store.continuation.yield(.verified(AdRemovalTransaction(id: 2, productID: "remove_ad", revoked: false)))
        for _ in 0..<100 where service.state.entitlement != .adFree { await Task.yield() }
        XCTAssertEqual(service.state.entitlement, .adFree)

        store.verificationFailure = AdRemovalVerificationFailure(transactionID: 3, reason: .invalidSignature)
        store.purchaseContinuation?.resume(throwing: AdRemovalPurchaseError.unverified)

        let result = await purchase.value
        XCTAssertEqual(result, .verificationFailed)
        XCTAssertEqual(service.state.entitlement, .adFree)
        XCTAssertFalse(service.state.entitlement.allowsAds)
        XCTAssertEqual(service.state.verificationFailure?.transactionID, 3)
    }

    func testRecoveredRefreshAppliesRightsBeforeFinishingAndClearsFailure() async {
        store.entitlement = .unknown
        store.verificationFailure = AdRemovalVerificationFailure(transactionID: 1, reason: .revokedCertificate)
        await service.refresh()
        XCTAssertNotNil(service.state.verificationFailure)
        store.entitlement = .adFree
        store.verificationFailure = nil
        store.onFinishVerified = { [weak service] in XCTAssertEqual(service?.state.entitlement, .adFree) }
        await service.refresh()
        XCTAssertEqual(store.finishVerifiedCount, 1)
        XCTAssertNil(service.state.verificationFailure)
        XCTAssertEqual(store.purchaseCount, 0)
        XCTAssertEqual(store.syncCount, 0)
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
        XCTAssertEqual(canRequest, .unavailable)
        withExtendedLifetime(subscription) {}
    }

    func testVerificationFailureResumesAdsAndVerifiedRecoveryRemovesThem() async {
        let configuration = BannerAdConfiguration(isDebug: true, isTesting: false,
            appID: BannerAdConfiguration.sampleAppID, bannerID: "", nativeID: "", localTestEnabled: true)
        let ads = BannerAdService(configuration: configuration, purchases: service)
        var enabled = true
        let subscription = ads.statePublisher.sink { enabled = $0.0 }
        XCTAssertFalse(enabled, "Initial checking must not flash ads to a purchaser")
        await prepare()
        store.purchaseError = AdRemovalPurchaseError.unverified
        store.verificationFailure = AdRemovalVerificationFailure(transactionID: 1, reason: .invalidSignature)
        let result = await service.purchase()
        XCTAssertEqual(result, .verificationFailed)
        XCTAssertTrue(enabled, "Verification failure must allow ads through the shared ad gate")
        XCTAssertFalse(SettingsPurchaseViewModel(purchases: service).canPurchase)
        XCTAssertTrue(store.finished.isEmpty)
        store.entitlement = .adFree
        store.verificationFailure = nil
        await service.refresh()
        XCTAssertFalse(enabled, "Verified recovery must remove ads again")
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

    func testRetryIsOfferedOnlyAfterPreparationFailsAndNeverWhileLoading() async {
        let viewModel = SettingsPurchaseViewModel(purchases: service)
        XCTAssertFalse(viewModel.shouldOfferRetry)
        store.productGate = true
        let preparation = Task { await viewModel.prepare() }
        while store.productContinuation == nil { await Task.yield() }
        XCTAssertTrue(viewModel.isPreparing)
        XCTAssertFalse(viewModel.shouldOfferRetry)
        store.productContinuation?.resume(returning: "$2.99")
        await preparation.value
        XCTAssertFalse(viewModel.isPreparing)
        XCTAssertFalse(viewModel.shouldOfferRetry)
        store.productGate = false
        store.productError = AdRemovalPurchaseError.unavailable
        await viewModel.prepare()
        XCTAssertTrue(viewModel.shouldOfferRetry)
        store.entitlement = .adFree
        await viewModel.prepare()
        XCTAssertFalse(viewModel.shouldOfferRetry)
    }

    func testTwoPurchaseScreensWaitForTheSameInFlightPriceBeforeOfferingRetry() async {
        store.productGate = true
        let first = SettingsPurchaseViewModel(purchases: service)
        let observed = ObservedPricePurchases(service: service)
        let reachedLookup = expectation(description: "second screen reaches shared product lookup")
        observed.onLoadProduct = { reachedLookup.fulfill() }
        let second = SettingsPurchaseViewModel(purchases: observed)
        let firstPreparation = Task { await first.prepare() }
        while store.productContinuation == nil { await Task.yield() }
        let secondPreparation = Task { await second.prepare() }
        await fulfillment(of: [reachedLookup], timeout: 2)
        XCTAssertTrue(second.isPreparing, "A pending shared request is not a failed price lookup")
        XCTAssertFalse(second.shouldOfferRetry)
        store.productContinuation?.resume(returning: "$2.99")
        await firstPreparation.value
        await secondPreparation.value
        XCTAssertTrue(first.canPurchase)
        XCTAssertTrue(second.canPurchase)
        XCTAssertFalse(second.shouldOfferRetry)
    }

    func testPurchaseScreenKeepsDetailsBehindSeparateInformationScreen() async {
        let model = SettingsPurchaseViewModel(purchases: service)
        await model.prepare()
        var contacts = 0
        let controller = PurchaseNoticeViewController(viewModel: model) { _ in contacts += 1 }
        let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        let buttons = purchaseDescendants(controller.view).compactMap { $0 as? UIButton }
        let buy = buttons.first { $0.accessibilityIdentifier == "ad_removal_buy" }!
        XCTAssertTrue(buy.configuration?.title?.contains("$2.99") == true)
        XCTAssertTrue(buy.isEnabled)
        XCTAssertTrue(buttons.first { $0.accessibilityIdentifier == "ad_removal_retry" }!.isHidden)
        let labels = purchaseDescendants(controller.view).compactMap { ($0 as? UILabel)?.text }
        XCTAssertFalse(labels.contains { $0.contains("Family Sharing") })
        let information = buttons.first { $0.accessibilityIdentifier == "ad_removal_information" }!
        information.sendActions(for: .touchUpInside)
        guard let details = navigation.topViewController as? PurchaseInformationViewController else {
            XCTFail("Information should open a separate screen")
            return
        }
        details.loadViewIfNeeded()
        let detailButtons = purchaseDescendants(details.view).compactMap { $0 as? UIButton }
        XCTAssertNotNil(detailButtons.first { $0.accessibilityIdentifier == "purchase_information_refund" })
        detailButtons.first { $0.accessibilityIdentifier == "purchase_information_contact" }!.sendActions(for: .touchUpInside)
        XCTAssertEqual(contacts, 1)
        XCTAssertEqual(store.purchaseCount, 0)
    }

    func testPurchasedScreenHasNoBuyOrRetryAndKeepsRestoreAndInformation() async {
        store.entitlement = .adFree
        let model = SettingsPurchaseViewModel(purchases: service)
        await model.prepare()
        let controller = PurchaseNoticeViewController(viewModel: model) { _ in }
        controller.loadViewIfNeeded()
        let buttons = purchaseDescendants(controller.view).compactMap { $0 as? UIButton }
        XCTAssertTrue(buttons.first { $0.accessibilityIdentifier == "ad_removal_buy" }!.isHidden)
        XCTAssertTrue(buttons.first { $0.accessibilityIdentifier == "ad_removal_retry" }!.isHidden)
        XCTAssertFalse(buttons.first { $0.accessibilityIdentifier == "ad_removal_restore" }!.isHidden)
        XCTAssertFalse(buttons.first { $0.accessibilityIdentifier == "ad_removal_information" }!.isHidden)
    }

    func testSettingsHasOnePurchaseEntryWithPurchasedStatus() async {
        store.entitlement = .adFree
        let model = SettingsPurchaseViewModel(purchases: service)
        await model.prepare()
        let controller = SettingViewController(analytics: NoOpAnalyticsClient(), purchaseViewModel: model)
        let navigation = UINavigationController(rootViewController: controller)
        controller.loadViewIfNeeded()
        let table = (controller.view as! SettingTableView).tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 4)
        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0))
        let content = cell.contentConfiguration as! UIListContentConfiguration
        XCTAssertEqual(content.text, "Ad removal".localized())
        XCTAssertEqual(content.secondaryText, "Ads removed".localized())
        controller.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 0))
        XCTAssertTrue(navigation.topViewController is PurchaseNoticeViewController)
        XCTAssertEqual(store.purchaseCount, 0)
    }

    private func purchaseDescendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + purchaseDescendants($0) }
    }

    func testPurchaseResultWaitsUntilReturningFromDetailedInformation() async {
        let model = SettingsPurchaseViewModel(purchases: service)
        await model.prepare()
        let purchase = PurchaseNoticeViewController(viewModel: model) { _ in }
        let navigation = UINavigationController(rootViewController: purchase)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.view.frame = window.bounds
        navigation.view.layoutIfNeeded()
        defer { window.isHidden = true }
        await settlePurchaseMessageUI()
        let information = purchaseDescendants(purchase.view).first {
            $0.accessibilityIdentifier == "ad_removal_information"
        } as! UIButton
        information.sendActions(for: .touchUpInside)
        await settlePurchaseMessageUI()
        XCTAssertTrue(navigation.topViewController is PurchaseInformationViewController)
        await model.restore()
        await settlePurchaseMessageUI()
        XCTAssertNotNil(model.message)
        XCTAssertNil(purchase.presentedViewController)
        XCTAssertNil(navigation.topViewController?.presentedViewController)
        navigation.popViewController(animated: false)
        XCTAssertTrue(navigation.topViewController === purchase)
        await settlePurchaseMessageUI()
        XCTAssertNotNil(purchase.viewIfLoaded?.window)
        XCTAssertNotNil(purchase.presentedViewController as? UIAlertController)
        XCTAssertNil(model.message)
        purchase.dismiss(animated: false)
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
        // 별도 테스트 창에서는 화면 표시 콜백을 명시적으로 호출한다.
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
        // 대기 중인 콜백이 실행되기 전에 다른 화면이 결과를 처리한 상황을 재현한다.
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
            XCTAssertEqual(table.numberOfRows(inSection: 0), 4)
            XCTAssertTrue(table.isScrollEnabled)
            if category.isAccessibilityCategory {
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
                let screens: [UIViewController] = [
                    PurchaseNoticeViewController(viewModel: viewModel, contact: { _ in }),
                    PurchaseInformationViewController(contact: { _ in })
                ]
                for controller in screens {
                let parent = UIViewController()
                parent.addChild(controller)
                controller.traitOverrides.preferredContentSizeCategory = category
                controller.overrideUserInterfaceStyle = style
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
                if category.isAccessibilityCategory {
                    XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
                }
                XCTAssertEqual(scroll.contentSize.width, scroll.bounds.width, accuracy: 1)
                XCTAssertEqual(store.purchaseCount, 0, "Opening purchase information must not start a purchase")
                for button in purchaseDescendants(controller.view).compactMap({ $0 as? UIButton }).filter({ !$0.isHidden }) {
                    guard let label = button.titleLabel else { continue }
                    if category.isAccessibilityCategory {
                        XCTAssertGreaterThan(label.font.pointSize, 30, "Purchase controls must follow Dynamic Type")
                    }
                    let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(required.height, label.bounds.height + 1, "The complete button title must fit")
                    let frame = label.convert(label.bounds, to: button)
                    XCTAssertGreaterThanOrEqual(frame.minY, -1)
                    XCTAssertLessThanOrEqual(frame.maxY, button.bounds.height + 1)
                }
                for bottom in [false, true] {
                    scroll.contentOffset.y = bottom ? max(0, scroll.contentSize.height - scroll.bounds.height) : 0
                    let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                    }
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "\(type(of: controller))-320-\(category.rawValue)-\(style.rawValue)-\(bottom ? "bottom" : "top")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                window.isHidden = true
                }
            }
        }
    }
}

@MainActor
private final class ObservedPricePurchases: AdRemovalPurchasing {
    let service: AdRemovalPurchaseService
    var onLoadProduct: (() -> Void)?
    init(service: AdRemovalPurchaseService) { self.service = service }
    var state: AdRemovalPurchaseState { service.state }
    var statePublisher: AnyPublisher<AdRemovalPurchaseState, Never> { service.statePublisher }
    func refresh() async { await service.refresh() }
    func loadProduct() async {
        onLoadProduct?()
        await service.loadProduct()
    }
    func purchase() async -> AdRemovalActionResult { await service.purchase() }
    func restore() async -> AdRemovalActionResult { await service.restore() }
}

@MainActor
private final class StubAdRemovalStore: AdRemovalStore {
    var verificationFailure: AdRemovalVerificationFailure?
    var finishVerifiedCount = 0
    var onFinishVerified: (() -> Void)?
    func finishVerifiedTransactions() async {
        finishVerifiedCount += 1
        onFinishVerified?()
    }
    var entitlement: AdRemovalEntitlement = .notPurchased
    var result: AdRemovalPurchaseResult = .success(AdRemovalTransaction(id: 1, productID: "remove_ad", revoked: false))
    var purchaseError: Error?
    var syncError: Error?
    var productError: Error?
    var productGate = false
    var productContinuation: CheckedContinuation<String, Error>?
    var finished: [UInt64] = []
    var syncCount = 0
    var purchaseCount = 0
    var onFinish: (() -> Void)?
    var purchaseGate = false
    var entitlementGate = false
    var purchaseContinuation: CheckedContinuation<AdRemovalPurchaseResult, Error>?
    var entitlementContinuation: CheckedContinuation<AdRemovalEntitlement, Never>?
    var continuation: AsyncStream<AdRemovalTransactionUpdate>.Continuation!

    func loadDisplayPrice() async throws -> String {
        if productGate { return try await withCheckedThrowingContinuation { productContinuation = $0 } }
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
        if purchaseGate { return try await withCheckedThrowingContinuation { purchaseContinuation = $0 } }
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
        // SKTestSession의 거래는 StoreKit 캐시에 비동기로 반영된다.
        // 즉시 조회된다고 가정하지 않고 반영될 때까지 기다린다.
        for _ in 0..<100 {
            let state = await store.currentEntitlement()
            if state == expected { return state }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return await store.currentEntitlement()
    }
}
