import Combine
import Foundation

@MainActor
final class SettingsPurchaseViewModel {
    @Published private(set) var state: AdRemovalPurchaseState
    @Published private(set) var message: String?
    private let purchases: any AdRemovalPurchasing
    private var subscription: AnyCancellable?

    init(purchases: any AdRemovalPurchasing) {
        self.purchases = purchases
        state = purchases.state
        subscription = purchases.statePublisher.sink { [weak self] in self?.state = $0 }
    }

    var canPurchase: Bool {
        state.entitlement == .notPurchased && state.displayPrice != nil && !state.isBusy && !state.pending
    }

    var purchaseDetail: String {
        if state.operation == .purchasing { return "Purchasing…".localized() }
        if state.entitlement == .adFree { return "Ads removed".localized() }
        if state.entitlement == .unknown && state.verificationFailure != nil {
            return "We could not verify your purchase. Do not buy again. Check purchases again, restore purchases, or contact the developer.".localized()
        }
        if state.pending { return "Awaiting purchase approval".localized() }
        switch state.entitlement {
        case .checking: return "Checking purchases…".localized()
        case .unknown: return "Unable to verify purchases. Tap to retry.".localized()
        default: return state.displayPrice ?? "Price unavailable. Tap to retry.".localized()
        }
    }

    func prepare() async {
        await purchases.refresh()
        await purchases.loadProduct()
    }

    func buy() async { show(await purchases.purchase()) }
    func restore() async { show(await purchases.restore()) }
    func clearMessage() { message = nil }

    private func show(_ result: AdRemovalActionResult) {
        switch result {
        case .purchased: message = "Ads have been removed.".localized()
        case .restored: message = "Your ad removal purchase has been restored.".localized()
        case .noPurchases: message = "No ad removal purchase was found for this Apple Account.".localized()
        case .pending: message = "Your purchase is awaiting approval. Ads will be removed once it is confirmed.".localized()
        case .verificationFailed: message = "We could not verify your purchase. Do not buy again. Check purchases again, restore purchases, or contact the developer.".localized()
        case .failed: message = "Unable to complete the request. Please try again or contact support.".localized()
        case .cancelled, .busy: break
        }
    }
}
