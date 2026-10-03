import Combine
import FirebaseCore
import FirebaseRemoteConfig
import GoogleMobileAds
import UIKit
import UnityAdapter
import UnityAds
import UserMessagingPlatform

@MainActor
protocol BannerAdServing: AnyObject {
    var configuration: BannerAdConfiguration { get }
    var statePublisher: AnyPublisher<(Bool, Bool), Never> { get }
    func prepare(from controller: UIViewController) async -> Bool
}

@MainActor
final class BannerAdService: BannerAdServing {
    @Published private(set) var enabled = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var consentAllowsAds = false

    let configuration: BannerAdConfiguration
    var statePublisher: AnyPublisher<(Bool, Bool), Never> {
        $enabled.combineLatest($consentAllowsAds).eraseToAnyPublisher()
    }
    private var remoteConfig: RemoteConfig?
    private var registration: ConfigUpdateListenerRegistration?
    private var foregroundSubscription: AnyCancellable?
    private var consentTask: Task<Bool, Never>?
    private var didCheckConsent = false
    private var didStartSDK = false
    private var isRefreshing = false

    init(configuration: BannerAdConfiguration = .current) {
        self.configuration = configuration
        guard configuration.hasAnyAdUnitID else { return }
        // Local validation stays independent of the production Remote Config switch.
        // Mediation validation requires a separate unit and still goes through UMP.
        if configuration.usesLocalTestAds || configuration.usesMediationTestAds {
            enabled = true
        } else if FirebaseApp.app() != nil {
            let remote = RemoteConfig.remoteConfig()
            remote.setDefaults([BannerAdConfiguration.remoteKey: NSNumber(value: false)])
            let settings = RemoteConfigSettings()
            settings.minimumFetchInterval = 300
            settings.fetchTimeout = 10
            remote.configSettings = settings
            remoteConfig = remote
            enabled = false
            registration = remote.addOnConfigUpdateListener { [weak self] update, error in
                Task { @MainActor in
                    guard let self, error == nil,
                          update?.updatedKeys.contains(BannerAdConfiguration.remoteKey) == true else { return }
                    do {
                        _ = try await remote.activate()
                        self.enabled = remote[BannerAdConfiguration.remoteKey].boolValue
                    } catch {
                        self.enabled = false
                    }
                }
            }
        }
        foregroundSubscription = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        Task { await refresh() }
    }

    deinit { registration?.remove() }

    func refresh() async {
        guard let remoteConfig, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            // Fetch on foreground, so returning users do not keep a stale ON switch.
            _ = try await remoteConfig.fetch(withExpirationDuration: 0)
            _ = try await remoteConfig.activate()
            enabled = remoteConfig[BannerAdConfiguration.remoteKey].boolValue
        } catch {
            // On an unavailable config service prefer the normal ad-free app.
            enabled = false
        }
    }

    func prepare(from controller: UIViewController) async -> Bool {
        guard enabled, configuration.hasAnyAdUnitID else { return false }
        if let consentTask { return await consentTask.value }
        if didCheckConsent { return consentAllowsAds }
        guard controller.viewIfLoaded?.window != nil,
              configuration.usesLocalTestAds || controller.presentedViewController == nil else { return false }

        let task = Task { @MainActor [weak self, weak controller] () -> Bool in
            guard let self, let controller else { return false }
            if self.configuration.usesLocalTestAds {
                // General Debug selects Google's sample ad units. Keep that local
                // verification path independent of production UMP configuration.
                if !self.didStartSDK {
                    self.didStartSDK = true
                    self.configureUnityAds()
                    await MobileAds.shared.start()
                }
                self.didCheckConsent = true
                self.consentAllowsAds = true
                return self.enabled
            }
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: consentParameters())
                guard self.enabled, controller.viewIfLoaded?.window != nil,
                      self.configuration.usesLocalTestAds || controller.presentedViewController == nil else { return false }
                try await ConsentForm.loadAndPresentIfRequired(from: controller)
            } catch {
                // UMP can still authorize requests using a valid prior consent choice.
                #if DEBUG
                if self.configuration.usesMediationTestAds {
                    print("[Ads validation] UMP: \(error.localizedDescription)")
                }
                #endif
            }
            self.didCheckConsent = true
            if self.enabled && ConsentInformation.shared.canRequestAds && !self.didStartSDK {
                self.didStartSDK = true
                self.configureUnityAds()
                await MobileAds.shared.start()
            }
            self.updateConsentState()
            return self.enabled && self.consentAllowsAds
        }
        consentTask = task
        let result = await task.value
        consentTask = nil
        return result
    }

    func presentPrivacyOptions(from controller: UIViewController) async throws {
        guard privacyOptionsRequired else { return }
        consentAllowsAds = false // Destroy existing ads before changing the choice.
        defer { updateConsentState() }
        try await ConsentForm.presentPrivacyOptionsForm(from: controller)
    }

    private func configureUnityAds() {
        // canRequestAds authorizes an ad request, not personalized advertising.
        // Until Unity-specific regional consent is verified, keep its ads contextual.
        let privacy = UADSMetaData()
        privacy.set("privacy.consent", value: false)
        privacy.commit()
        GADMediationAdapterUnity.testMode = configuration.usesLocalTestAds || configuration.usesMediationTestAds
        #if DEBUG
        if configuration.usesMediationTestAds {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = debugDeviceIDs("TK8_ADMOB_TEST_DEVICE_IDS")
        }
        #endif
    }

    private func consentParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        if configuration.usesMediationTestAds {
            let debug = DebugSettings()
            debug.testDeviceIdentifiers = debugDeviceIDs("TK8_UMP_TEST_DEVICE_IDS")
            if ProcessInfo.processInfo.arguments.contains("-TK8UMPForceEEA") {
                debug.geography = .EEA
            }
            parameters.debugSettings = debug
            if ProcessInfo.processInfo.arguments.contains("-TK8UMPResetConsent") {
                ConsentInformation.shared.reset()
            }
        }
        #endif
        return parameters
    }

    #if DEBUG
    private func debugDeviceIDs(_ key: String) -> [String] {
        (ProcessInfo.processInfo.environment[key] ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func presentAdInspector(from controller: UIViewController) async throws {
        guard configuration.usesMediationTestAds, didStartSDK else {
            throw NSError(domain: "TK8AdsValidation", code: 1)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            MobileAds.shared.presentAdInspector(from: controller) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
    #endif

    private func updateConsentState() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        consentAllowsAds = ConsentInformation.shared.canRequestAds
        #if DEBUG && !targetEnvironment(simulator)
        // A real AdMob unit must not request Google inventory on an unregistered phone.
        if configuration.usesMediationTestAds && debugDeviceIDs("TK8_ADMOB_TEST_DEVICE_IDS").isEmpty {
            consentAllowsAds = false
            print("[Ads validation] Register the AdMob test device ID before requesting this validation unit.")
        }
        #endif
    }
}
