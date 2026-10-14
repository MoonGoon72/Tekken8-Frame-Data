import Foundation
import StoreKit

@MainActor
final class StoreKitAdRemovalStore: AdRemovalStore {
    private var product: Product?
    private var transactions: [UInt64: Transaction] = [:]

    func loadDisplayPrice() async throws -> String {
        let products = try await Product.products(for: [AdRemovalPurchaseService.productID])
        guard let product = products.first(where: {
            $0.id == AdRemovalPurchaseService.productID && $0.type == .nonConsumable
        }) else { throw AdRemovalPurchaseError.unavailable }
        self.product = product
        return product.displayPrice
    }

    func currentEntitlement() async -> AdRemovalEntitlement {
        var hasUnverified = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard transaction.productID == AdRemovalPurchaseService.productID,
                      transaction.productType == .nonConsumable else { continue }
                if transaction.revocationDate == nil { return .adFree }
            case .unverified(let transaction, _):
                if transaction.productID == AdRemovalPurchaseService.productID { hasUnverified = true }
            }
        }
        return hasUnverified ? .unknown : .notPurchased
    }

    func purchase() async throws -> AdRemovalPurchaseResult {
        guard let product else { throw AdRemovalPurchaseError.unavailable }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result,
                  transaction.productID == AdRemovalPurchaseService.productID,
                  transaction.productType == .nonConsumable else {
                throw AdRemovalPurchaseError.unverified
            }
            transactions[transaction.id] = transaction
            return .success(Self.map(transaction))
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: throw AdRemovalPurchaseError.unavailable
        }
    }

    func sync() async throws { try await AppStore.sync() }

    func updates() -> AsyncStream<AdRemovalTransactionUpdate> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                // Subscribe immediately at app startup, including interrupted purchases.
                for await result in Transaction.unfinished {
                    guard !Task.isCancelled else { break }
                    self?.emit(result, into: continuation)
                }
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    self?.emit(result, into: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func finish(_ transaction: AdRemovalTransaction) async {
        guard let value = transactions.removeValue(forKey: transaction.id) else { return }
        await value.finish()
    }

    private func emit(_ result: VerificationResult<Transaction>, into continuation: AsyncStream<AdRemovalTransactionUpdate>.Continuation) {
        switch result {
        case .verified(let transaction):
            guard transaction.productID == AdRemovalPurchaseService.productID,
                  transaction.productType == .nonConsumable else { return }
            transactions[transaction.id] = transaction
            continuation.yield(.verified(Self.map(transaction)))
        case .unverified(let transaction, _):
            guard transaction.productID == AdRemovalPurchaseService.productID else { return }
            continuation.yield(.unverified)
        }
    }

    private static func map(_ transaction: Transaction) -> AdRemovalTransaction {
        AdRemovalTransaction(id: transaction.id, productID: transaction.productID, revoked: transaction.revocationDate != nil)
    }
}
