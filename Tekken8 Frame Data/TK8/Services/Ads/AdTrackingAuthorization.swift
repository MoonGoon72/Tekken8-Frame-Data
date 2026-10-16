import AppTrackingTransparency
import GoogleMobileAds
import UIKit

/// iOS owns the decision across launches; never persist a second permission flag.
@MainActor
final class AdTrackingAuthorization {
    private let status: () -> ATTrackingManager.AuthorizationStatus
    private let request: () async -> ATTrackingManager.AuthorizationStatus
    private let isActive: () -> Bool
    private var pending: Task<ATTrackingManager.AuthorizationStatus, Never>?

    init(
        status: @escaping () -> ATTrackingManager.AuthorizationStatus = { ATTrackingManager.trackingAuthorizationStatus },
        request: @escaping () async -> ATTrackingManager.AuthorizationStatus = {
            await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { continuation.resume(returning: $0) }
            }
        },
        isActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
    ) {
        self.status = status
        self.request = request
        self.isActive = isActive
    }

    func requestIfNeeded(when canPresent: @escaping () -> Bool = { true }) async -> ATTrackingManager.AuthorizationStatus {
        let currentStatus = status()
        if let pending { return await pending.value }
        guard currentStatus == .notDetermined else { return currentStatus }
        let task = Task { @MainActor in
            // UMP/system dialogs can temporarily make the app inactive.
            while !self.isActive() {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return self.status() }
            }
            guard self.status() == .notDetermined, canPresent() else { return self.status() }
            return await self.request()
        }
        pending = task
        let result = await task.value
        pending = nil
        return result
    }
}

/// ATT is an additional gate; an authorized default request still obeys UMP.
enum AdRequestFactory {
    static func nonPersonalizedParameters(for status: ATTrackingManager.AuthorizationStatus) -> [String: String] {
        status == .authorized ? [:] : ["npa": "1"]
    }

    static func make() -> Request {
        let request = Request()
        let parameters = nonPersonalizedParameters(for: ATTrackingManager.trackingAuthorizationStatus)
        if !parameters.isEmpty {
            let extras = Extras()
            extras.additionalParameters = parameters
            request.register(extras)
        }
        return request
    }
}
