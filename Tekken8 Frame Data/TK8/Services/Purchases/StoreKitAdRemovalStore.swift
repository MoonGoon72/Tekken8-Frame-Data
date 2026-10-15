import Foundation
import StoreKit

@MainActor
final class StoreKitAdRemovalStore: AdRemovalStore {
    private let recovery = AdRemovalVerificationRecovery()
    var verificationFailure: AdRemovalVerificationFailure? { recovery.failure }
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
        var verifiedPurchase = false
        // 앱을 다시 시작하면 미해결 구매부터 확인한다. 빈 권한 조회 결과만으로
        // 미구매라고 판단해 재구매를 허용하는 일을 방지한다.
        for await result in Transaction.unfinished {
            if case .unverified(let transaction, let error) = result,
               transaction.productID == AdRemovalPurchaseService.productID {
                recovery.record(Self.failure(transaction, error))
            }
        }
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard isTarget(transaction) else { continue }
                let wasUnresolved = recovery.failures[transaction.id] != nil
                recovery.verified(Self.map(transaction))
                if wasUnresolved { transactions[transaction.id] = transaction }
                if transaction.revocationDate == nil { verifiedPurchase = true }
            case .unverified(let transaction, let error):
                guard transaction.productID == AdRemovalPurchaseService.productID else { continue }
                recovery.record(Self.failure(transaction, error))
            }
        }
        // 권한을 다시 확인하는 시점마다 미해결 거래를 각각 한 번 재조회한다.
        for failure in Array(recovery.failures.values) {
            if let transaction = await recover(failure, retry: true), !transaction.revoked {
                verifiedPurchase = true
            }
        }
        if verifiedPurchase { return .adFree }
        return recovery.failure == nil ? .notPurchased : .unknown
    }

    func finishVerifiedTransactions() async {
        // 서비스가 확인된 구매 권한을 적용한 뒤에만 호출한다.
        for transaction in Array(transactions.values) { await finish(Self.map(transaction)) }
    }

    func purchase() async throws -> AdRemovalPurchaseResult {
        guard let product else { throw AdRemovalPurchaseError.unavailable }
        switch try await product.purchase() {
        case .success(let result):
            switch result {
            case .verified(let transaction):
                guard isTarget(transaction) else { throw AdRemovalPurchaseError.unverified }
                recovery.verified(Self.map(transaction))
                transactions[transaction.id] = transaction
                return .success(Self.map(transaction))
            case .unverified(let transaction, let error):
                guard transaction.productID == AdRemovalPurchaseService.productID else { throw AdRemovalPurchaseError.unverified }
                if let recovered = await recover(Self.failure(transaction, error)) {
                    return .success(recovered)
                }
                throw AdRemovalPurchaseError.unverified
            }
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: throw AdRemovalPurchaseError.unavailable
        }
    }

    func sync() async throws { try await AppStore.sync() }

    func updates() -> AsyncStream<AdRemovalTransactionUpdate> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                // 중단된 구매도 처리할 수 있도록 앱 시작부터 미완료 거래와 갱신을 확인한다.
                for await result in Transaction.unfinished {
                    guard !Task.isCancelled else { break }
                    await self?.emit(result, into: continuation)
                }
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    await self?.emit(result, into: continuation)
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

    private func emit(_ result: VerificationResult<Transaction>, into continuation: AsyncStream<AdRemovalTransactionUpdate>.Continuation) async {
        switch result {
        case .verified(let transaction):
            guard transaction.productID == AdRemovalPurchaseService.productID,
                  transaction.productType == .nonConsumable else { return }
            recovery.verified(Self.map(transaction))
            transactions[transaction.id] = transaction
            continuation.yield(.verified(Self.map(transaction)))
        case .unverified(let transaction, let error):
            guard transaction.productID == AdRemovalPurchaseService.productID else { return }
            if let recovered = await recover(Self.failure(transaction, error)) {
                guard !Task.isCancelled else { return }
                continuation.yield(.verified(recovered))
            } else {
                guard !Task.isCancelled else { return }
                continuation.yield(.unverified)
            }
        }
    }

    private func isTarget(_ transaction: Transaction) -> Bool {
        transaction.productID == AdRemovalPurchaseService.productID && transaction.productType == .nonConsumable
    }

    private func recover(_ failure: AdRemovalVerificationFailure, retry: Bool = false) async -> AdRemovalTransaction? {
        await recovery.resolve(failure, retry: retry) { [weak self] id in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return .missing }
            // StoreKit 거래만 다시 조회한다. 구매를 재요청하거나 사용자 요청 없이 동기화하지 않는다.
            guard let self, let result = await Transaction.latest(for: AdRemovalPurchaseService.productID) else { return .missing }
            switch result {
            case .verified(let transaction):
                guard self.isTarget(transaction), transaction.id == id else { return .missing }
                self.transactions[transaction.id] = transaction
                return .verified(Self.map(transaction))
            case .unverified(let transaction, let error):
                return .unverified(Self.failure(transaction, error))
            }
        }
    }

    private static func failure(_ transaction: Transaction, _ error: VerificationResult<Transaction>.VerificationError) -> AdRemovalVerificationFailure {
        let reason: AdRemovalVerificationFailure.Reason
        switch error {
        case .invalidCertificateChain: reason = .invalidCertificateChain
        case .invalidDeviceVerification: reason = .invalidDeviceVerification
        case .invalidEncoding: reason = .invalidEncoding
        case .invalidSignature: reason = .invalidSignature
        case .missingRequiredProperties: reason = .missingRequiredProperties
        case .revokedCertificate: reason = .revokedCertificate
        @unknown default: reason = .unexpected
        }
        return AdRemovalVerificationFailure(transactionID: transaction.id, reason: reason)
    }

    private static func map(_ transaction: Transaction) -> AdRemovalTransaction {
        AdRemovalTransaction(id: transaction.id, productID: transaction.productID, revoked: transaction.revocationDate != nil)
    }
}
