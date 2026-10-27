import Combine

@MainActor
final class AdRemovalNoticeViewModel {
    @Published private(set) var isEligible = false
    private let repository: any AdRemovalNoticeRepository
    private var consumed: Bool
    private var subscription: AnyCancellable?

    init(purchases: any AdRemovalPurchasing, repository: any AdRemovalNoticeRepository) {
        self.repository = repository
        consumed = repository.isConsumed
        isEligible = !consumed && purchases.state.entitlement == .notPurchased
        subscription = purchases.statePublisher.sink { [weak self] state in
            guard let self else { return }
            self.isEligible = !self.consumed && state.entitlement == .notPurchased
        }
    }

    func consume() {
        consumed = true
        repository.consume()
        isEligible = false
    }
}
