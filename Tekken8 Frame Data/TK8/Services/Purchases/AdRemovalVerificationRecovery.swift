import Foundation

struct AdRemovalVerificationFailure: Equatable {
    enum Reason: Equatable {
        case invalidCertificateChain, invalidDeviceVerification, invalidEncoding
        case invalidSignature, missingRequiredProperties, revokedCertificate
        case unexpected, transactionMismatch
    }
    let transactionID: UInt64
    let reason: Reason
}

enum AdRemovalVerificationLookup {
    case verified(AdRemovalTransaction)
    case unverified(AdRemovalVerificationFailure)
    case missing
}

/// 검증이 끝나지 않은 거래를 확인된 구매 권한과 분리해 관리한다.
@MainActor
final class AdRemovalVerificationRecovery {
    private(set) var failures: [UInt64: AdRemovalVerificationFailure] = [:]
    private var resolved: [UInt64: AdRemovalTransaction] = [:]
    private var attempted = Set<UInt64>()
    private var requests: [UInt64: Task<AdRemovalVerificationLookup, Never>] = [:]

    var failure: AdRemovalVerificationFailure? {
        failures.keys.sorted().first.flatMap { failures[$0] }
    }

    func record(_ failure: AdRemovalVerificationFailure) {
        guard resolved[failure.transactionID] == nil else { return }
        failures[failure.transactionID] = failure
    }
    func verified(_ transaction: AdRemovalTransaction) {
        failures.removeValue(forKey: transaction.id)
        resolved[transaction.id] = transaction
    }

    func resolve(_ failure: AdRemovalVerificationFailure, retry: Bool = false,
                 lookup: @escaping (UInt64) async -> AdRemovalVerificationLookup) async -> AdRemovalTransaction? {
        let id = failure.transactionID
        if let transaction = resolved[id] { return transaction }
        record(failure)
        let request: Task<AdRemovalVerificationLookup, Never>
        if let existing = requests[id] {
            request = existing
        } else {
            guard retry || !attempted.contains(id) else { return nil }
            attempted.insert(id)
            request = Task { await lookup(id) }
            requests[id] = request
        }
        let result = await request.value
        requests[id] = nil
        // 재조회 중 검증된 갱신이 도착했다면, 늦게 반환된 실패보다 우선한다.
        if let transaction = resolved[id] { return transaction }
        switch result {
        case .verified(let transaction):
            guard transaction.id == id, transaction.productID == AdRemovalPurchaseService.productID else {
                record(AdRemovalVerificationFailure(transactionID: id, reason: .transactionMismatch))
                return nil
            }
            verified(transaction)
            return transaction
        case .unverified(let next) where next.transactionID == id:
            record(next)
        default: break // 조회 결과가 없더라도 미해결 구매를 미구매로 판단하지 않는다.
        }
        return nil
    }
}
