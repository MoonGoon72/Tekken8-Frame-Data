import Combine
import GoogleMobileAds
import UIKit

@MainActor
final class NativeMoveAdLoader: NSObject, NativeAdLoaderDelegate, NativeAdDelegate {
    private let service: any BannerAdServing
    private let analytics: AnalyticsClient
    private var adLoaders: [Int: AdLoader] = [:]
    private var loaderPlacements: [ObjectIdentifier: Int] = [:]
    private var loadingPlacements = Set<Int>()
    private weak var controller: UIViewController?
    private var requestedPlacements = [Int]()
    private var stateSubscription: AnyCancellable?
    private var adsAreAllowed = false
    private var requestGeneration = 0

    private(set) var nativeAds: [Int: NativeAd] = [:] {
        didSet { onAdsChanged?() }
    }
    var onAdsChanged: (() -> Void)?

    init(service: any BannerAdServing, analytics: AnalyticsClient) {
        self.service = service
        self.analytics = analytics
        super.init()
        stateSubscription = service.statePublisher
            .sink { [weak self] enabled, consent in
                self?.updateAdState(enabled: enabled, consent: consent)
            }
    }

    func load(placements: [Int], from controller: UIViewController) {
        guard let adUnitID = service.configuration.nativeAdUnitID else { return }
        self.controller = controller
        requestedPlacements = placements
        for placement in placements where nativeAds[placement] == nil && !loadingPlacements.contains(placement) {
            loadingPlacements.insert(placement)
            let generation = requestGeneration
            Task { [weak self, weak controller] in
                guard let self, let controller else { return }
                let canRequest = await self.service.prepare(from: controller)
                guard canRequest,
                      self.requestGeneration == generation,
                      controller.viewIfLoaded?.window != nil else {
                    self.removeLoadingPlacement(placement, generation: generation)
                    return
                }
                let loader = AdLoader(adUnitID: adUnitID, rootViewController: controller, adTypes: [.native], options: nil)
                loader.delegate = self
                self.adLoaders[placement] = loader
                self.loaderPlacements[ObjectIdentifier(loader)] = placement
                loader.load(Request())
            }
        }
    }

    func nativeAd(for placement: Int) -> NativeAd? { nativeAds[placement] }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        guard let placement = loaderPlacements[ObjectIdentifier(adLoader)] else { return }
        removeLoader(for: placement)
        guard adsAreAllowed, controller?.viewIfLoaded?.window != nil else {
            nativeAd.delegate = nil
            return
        }
        nativeAd.delegate = self
        nativeAds[placement] = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        guard let placement = loaderPlacements[ObjectIdentifier(adLoader)] else { return }
        analytics.log(.nativeAdLoadFailed(placement: .moveList, code: (error as NSError).code))
        removeLoader(for: placement)
    }

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        guard adsAreAllowed,
              nativeAds.values.contains(where: { $0 === nativeAd }) else { return }
        analytics.log(.nativeAdImpression(placement: .moveList))
    }

    private func removeLoader(for placement: Int) {
        if let loader = adLoaders.removeValue(forKey: placement) {
            loaderPlacements.removeValue(forKey: ObjectIdentifier(loader))
        }
        loadingPlacements.remove(placement)
    }

    private func removeLoadingPlacement(_ placement: Int, generation: Int) {
        guard requestGeneration == generation else { return }
        loadingPlacements.remove(placement)
    }

    private func updateAdState(enabled: Bool, consent: Bool) {
        let allowed = enabled && consent
        guard allowed != adsAreAllowed else { return }
        adsAreAllowed = allowed

        guard allowed else {
            requestGeneration += 1
            nativeAds.values.forEach { $0.delegate = nil }
            nativeAds.removeAll()
            adLoaders.removeAll()
            loaderPlacements.removeAll()
            loadingPlacements.removeAll()
            return
        }

        guard let controller, controller.viewIfLoaded?.window != nil else { return }
        load(placements: requestedPlacements, from: controller)
    }
}
