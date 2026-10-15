import XCTest
@testable import TK8

@MainActor
final class AdRemovalVerificationRecoveryTests: XCTestCase {
    private let failure = AdRemovalVerificationFailure(transactionID: 10, reason: .invalidCertificateChain)
    private let verified = AdRemovalTransaction(id: 10, productID: "remove_ad", revoked: false)

    func testAutomaticLookupRunsOnceAndExplicitRetryCanRecover() async {
        let recovery = AdRemovalVerificationRecovery()
        var queries = 0
        let first = await recovery.resolve(failure) { _ in queries += 1; return .unverified(self.failure) }
        let duplicate = await recovery.resolve(failure) { _ in queries += 1; return .verified(self.verified) }
        XCTAssertNil(first)
        XCTAssertNil(duplicate)
        XCTAssertEqual(queries, 1)
        XCTAssertEqual(recovery.failure, failure)
        let result = await recovery.resolve(failure, retry: true) { _ in queries += 1; return .verified(self.verified) }
        XCTAssertEqual(result, verified)
        XCTAssertEqual(queries, 2)
        XCTAssertNil(recovery.failure)
    }

    func testMissingOrDifferentTransactionDoesNotResolveOriginalPurchase() async {
        let recovery = AdRemovalVerificationRecovery()
        let missing = await recovery.resolve(failure) { _ in .missing }
        XCTAssertNil(missing)
        XCTAssertEqual(recovery.failure, failure)
        let wrong = await recovery.resolve(failure, retry: true) { _ in
            .verified(AdRemovalTransaction(id: 99, productID: "remove_ad", revoked: false))
        }
        XCTAssertNil(wrong)
        XCTAssertEqual(recovery.failure?.reason, .transactionMismatch)
    }

    func testNewVerificationErrorIsPreserved() async {
        let recovery = AdRemovalVerificationRecovery()
        let next = AdRemovalVerificationFailure(transactionID: 10, reason: .revokedCertificate)
        _ = await recovery.resolve(failure) { _ in .unverified(next) }
        XCTAssertEqual(recovery.failure, next)
    }

    func testConcurrentPurchaseAndUpdateShareOneLookupAndFreshVerifiedUpdateWins() async {
        let recovery = AdRemovalVerificationRecovery()
        var continuation: CheckedContinuation<AdRemovalVerificationLookup, Never>?
        var queries = 0
        let first = Task { await recovery.resolve(self.failure) { _ in
            queries += 1
            return await withCheckedContinuation { continuation = $0 }
        } }
        while continuation == nil { await Task.yield() }
        let second = Task { await recovery.resolve(self.failure) { _ in
            queries += 1
            return .missing
        } }
        await Task.yield()
        recovery.verified(verified)
        continuation?.resume(returning: .unverified(failure))
        let a = await first.value
        let b = await second.value
        XCTAssertEqual(a, verified)
        XCTAssertEqual(b, verified)
        XCTAssertEqual(queries, 1)
        XCTAssertNil(recovery.failure)
    }
}
