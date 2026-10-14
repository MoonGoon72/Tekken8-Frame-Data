import Combine
import Foundation
import UIKit

enum AdRemovalEntitlement: Equatable {
    case checking, unknown, notPurchased, adFree

    var allowsAds: Bool { self == .notPurchased }
}

struct AdRemovalPurchaseState: Equatable {
    enum Operation { case idle, purchasing, restoring }
    var entitlement: AdRemovalEntitlement = .checking
    var displayPrice: String?
    var operation: Operation = .idle
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
    case purchased, restored, noPurchases, cancelled, pending, failed, busy
}

@MainActor
protocol AdRemovalStore: AnyObject {
    func loadDisplayPrice() async throws -> String
    func currentEntitlement() async -> AdRemovalEntitlement
    func purchase() async throws -> AdRemovalPurchaseResult
    func sync() async throws
    func updates() -> AsyncStream<AdRemovalTransactionUpdate>
    func finish(_ transaction: AdRemovalTransaction) async
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

/// StoreKit's signed transactions are the only source of purchase rights.
/// Unknown rights suppress advertising without granting or persisting a purchase.
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
                state.pending = false
                // Rights are delivered (including removing existing ads) before finish.
                await store.finish(transaction)
                return state.entitlement == .adFree ? .purchased : .failed
            case .cancelled: return .cancelled
            case .pending:
                state.pending = true
                return .pending
            }
        } catch AdRemovalPurchaseError.unverified {
            invalidateRefresh()
            state.entitlement = .unknown
            return .failed
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
            default: return .failed
            }
        } catch {
            // A failed forced sync does not erase a locally verified purchase.
            if state.entitlement != .adFree { state.entitlement = .unknown }
            return .failed
        }
    }

    private func handle(_ update: AdRemovalTransactionUpdate) async {
        invalidateRefresh()
        switch update {
        case .unverified:
            state.entitlement = .unknown
        case .verified(let transaction):
            guard transaction.productID == Self.productID else { return }
            state.pending = false
            if transaction.revoked {
                // An old refund must not revoke a newer purchase of the product.
                await refresh()
            } else {
                // A verified update delivers rights immediately; the entitlement
                // snapshot can lag behind a newly approved transaction.
                state.entitlement = .adFree
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
