import Combine
import Foundation
import UIKit

enum AdRemovalEntitlement: Equatable {
    case checking, unknown, notPurchased, adFree

    var allowsAds: Bool { self == .notPurchased || self == .unknown }
}

struct AdRemovalPurchaseState: Equatable {
    enum Operation { case idle, purchasing, restoring }
    var entitlement: AdRemovalEntitlement = .checking
    var displayPrice: String?
    var operation: Operation = .idle
    var verificationFailure: AdRemovalVerificationFailure?
    var pending = false
    var isBusy: Bool { operation != .idle }
}

struct AdRemovalTransaction: Equatable {
    let id: UInt64
    let productID: String
    let revoked: Bool
}

enum AdRemovalTransactionUpdate {
    case verified(AdRemovalTransaction)
    case unverified
}

enum AdRemovalPurchaseResult {
    case success(AdRemovalTransaction), cancelled, pending
}

enum AdRemovalPurchaseError: Error {
    case unavailable, unverified
}

enum AdRemovalActionResult: Equatable {
    case purchased, restored, noPurchases, cancelled, pending, failed, verificationFailed, busy
}

@MainActor
protocol AdRemovalStore: AnyObject {
    var verificationFailure: AdRemovalVerificationFailure? { get }
    func finishVerifiedTransactions() async
    func loadDisplayPrice() async throws -> String
    func currentEntitlement() async -> AdRemovalEntitlement
    func purchase() async throws -> AdRemovalPurchaseResult
    func sync() async throws
    func updates() -> AsyncStream<AdRemovalTransactionUpdate>
    func finish(_ transaction: AdRemovalTransaction) async
}

extension AdRemovalStore {
    var verificationFailure: AdRemovalVerificationFailure? { nil }
    func finishVerifiedTransactions() async {}
}

@MainActor
protocol AdRemovalPurchasing: AnyObject {
    var state: AdRemovalPurchaseState { get }
    var statePublisher: AnyPublisher<AdRemovalPurchaseState, Never> { get }
    func refresh() async
    func loadProduct() async
    func purchase() async -> AdRemovalActionResult
    func restore() async -> AdRemovalActionResult
}

/// 구매 권한은 StoreKit이 검증한 서명된 거래만 근거로 판단한다.
/// 초기 확인 이후에는 권한 확인 실패 상태에서도 광고를 허용하지만, 구매 권한은 부여하지 않는다.
@MainActor
final class AdRemovalPurchaseService: AdRemovalPurchasing {
    static let productID = "remove_ad"
    @Published private(set) var state = AdRemovalPurchaseState()
    var statePublisher: AnyPublisher<AdRemovalPurchaseState, Never> { $state.eraseToAnyPublisher() }

    private let store: any AdRemovalStore
    private var listener: Task<Void, Never>?
    private var foreground: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var loadingProduct = false

    init(store: any AdRemovalStore, startsAutomatically: Bool = true) {
        self.store = store
        if startsAutomatically { start() }
    }

    deinit {
        listener?.cancel()
        refreshTask?.cancel()
    }

    func start() {
        guard listener == nil else { return }
        let updates = store.updates()
        listener = Task { [weak self] in
            for await update in updates {
                guard !Task.isCancelled else { return }
                await self?.handle(update)
            }
        }
        foreground = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        Task { [weak self] in await self?.refresh() }
    }

    func refresh() async {
        if let refreshTask { await refreshTask.value; return }
        let generation = refreshGeneration
        let store = store
        let task = Task { [weak self] in
            let entitlement = await store.currentEntitlement()
            guard !Task.isCancelled, let self, generation == self.refreshGeneration else { return }
            self.state.entitlement = entitlement
            self.state.verificationFailure = entitlement == .unknown ? store.verificationFailure : nil
            if entitlement == .adFree || entitlement == .notPurchased {
                await store.finishVerifiedTransactions()
            }
        }
        refreshTask = task
        await task.value
        if generation == refreshGeneration { refreshTask = nil }
    }

    func loadProduct() async {
        guard !loadingProduct else { return }
        loadingProduct = true
        defer { loadingProduct = false }
        do { state.displayPrice = try await store.loadDisplayPrice() }
        catch { state.displayPrice = nil }
    }

    func purchase() async -> AdRemovalActionResult {
        guard !state.isBusy, !state.pending else { return .busy }
        guard state.entitlement != .adFree else { return .purchased }
        guard state.entitlement == .notPurchased, state.displayPrice != nil else { return .failed }
        state.operation = .purchasing
        defer { state.operation = .idle }
        do {
            switch try await store.purchase() {
            case .success(let transaction):
                guard transaction.productID == Self.productID, !transaction.revoked else { return .failed }
                invalidateRefresh()
                state.entitlement = .adFree
                state.verificationFailure = nil
                state.pending = false
                // 광고 제거를 포함한 구매 권한을 먼저 적용한 뒤 거래를 종료한다.
                await store.finish(transaction)
                return state.entitlement == .adFree ? .purchased : .failed
            case .cancelled: return .cancelled
            case .pending:
                state.pending = true
                return .pending
            }
        } catch AdRemovalPurchaseError.unverified {
            invalidateRefresh()
            if state.entitlement != .adFree { state.entitlement = .unknown }
            state.verificationFailure = store.verificationFailure
            return .verificationFailed
        } catch { return .failed }
    }

    func restore() async -> AdRemovalActionResult {
        guard !state.isBusy else { return .busy }
        state.operation = .restoring
        defer { state.operation = .idle }
        do {
            try await store.sync()
            invalidateRefresh()
            await refresh()
            switch state.entitlement {
            case .adFree: return .restored
            case .notPurchased: return .noPurchases
            case .unknown: return .verificationFailed
            default: return .failed
            }
        } catch {
            // 강제 동기화가 실패해도 이미 로컬에서 검증된 구매 권한은 지우지 않는다.
            if state.entitlement != .adFree { state.entitlement = .unknown }
            return .failed
        }
    }

    private func handle(_ update: AdRemovalTransactionUpdate) async {
        invalidateRefresh()
        switch update {
        case .unverified:
            if state.entitlement != .adFree { state.entitlement = .unknown }
            state.verificationFailure = store.verificationFailure
        case .verified(let transaction):
            guard transaction.productID == Self.productID else { return }
            state.pending = false
            if transaction.revoked {
                // 이전 거래의 환불로 같은 상품의 새 구매 권한까지 회수하지 않도록 재확인한다.
                await refresh()
            } else {
                // 현재 권한 조회에는 새로 승인된 거래가 아직 반영되지 않았을 수 있다.
                // 따라서 검증된 거래 갱신을 받으면 구매 권한을 즉시 적용한다.
                state.entitlement = .adFree
                state.verificationFailure = nil
            }
            await store.finish(transaction)
        }
    }

    private func invalidateRefresh() {
        refreshGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
    }
}
