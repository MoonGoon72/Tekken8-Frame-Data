import Combine
import GoogleMobileAds
import UIKit

/// Owns an ad only while its screen is eligible. Never changes the screen's data source.
@MainActor
final class BannerAdHost: NSObject, BannerViewDelegate {
    private weak var controller: UIViewController?
    private let service: any BannerAdServing
    private let loadAd: (BannerView) -> Void
    private let isApplicationActive: () -> Bool
    private let placement: BannerPlacement
    private let analytics: AnalyticsClient
    private let container = UIView()
    private var height: NSLayoutConstraint!
    private var fullContentBottom: NSLayoutConstraint!
    private var adContentBottom: NSLayoutConstraint!
    private var subscriptions = Set<AnyCancellable>()
    private var policy = BannerAdPolicy()
    private var banner: BannerView?
    private var requestedWidth: CGFloat = 0
    private var failedThisVisit = false
    private var preparing = false
    private var impressionRecorded = false

    init(service: any BannerAdServing, placement: BannerPlacement, analytics: AnalyticsClient,
         loadAd: @escaping (BannerView) -> Void = { $0.load(Request()) },
         isApplicationActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }) {
        self.service = service
        self.placement = placement
        self.analytics = analytics
        self.loadAd = loadAd
        self.isApplicationActive = isApplicationActive
    }

    func install(in controller: UIViewController) {
        self.controller = controller
        let content = controller.view!
        let wrapper = UIView()
        wrapper.backgroundColor = content.backgroundColor ?? .tkBackground
        controller.view = wrapper
        wrapper.addSubview(content)
        wrapper.addSubview(container)
        content.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.isHidden = true
        container.accessibilityIdentifier = "admob_banner_" + placement.rawValue
        height = container.heightAnchor.constraint(equalToConstant: 0)
        fullContentBottom = content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        adContentBottom = content.bottomAnchor.constraint(equalTo: container.topAnchor)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            fullContentBottom,
            container.leadingAnchor.constraint(equalTo: wrapper.safeAreaLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapper.safeAreaLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: wrapper.safeAreaLayoutGuide.bottomAnchor), height
        ])
        service.statePublisher
            .sink { [weak self] enabled, consent in
                guard let self else { return }
                if enabled != self.policy.enabled || consent != self.policy.consentAllowsAds {
                    self.failedThisVisit = false
                }
                self.policy.enabled = enabled
                self.policy.consentAllowsAds = consent
                self.update()
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .sink { [weak self] notification in
                guard let self, let window = self.controller?.viewIfLoaded?.window,
                      let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let keyboard = window.convert(frame, from: nil)
                self.policy.keyboardVisible = window.bounds.intersection(keyboard).height > 0
                self.update()
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.policy.keyboardVisible = false
                self?.update()
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.removeBanner() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.update() }.store(in: &subscriptions)
    }

    func appear() {
        policy.visible = true
        failedThisVisit = false
        update()
    }

    func disappear() {
        policy.visible = false
        removeBanner()
    }

    func setEditing(_ editing: Bool) {
        policy.editing = editing
        update()
    }

    func layout() {
        if let controller, requestedWidth != 0,
           abs(controller.view.safeAreaLayoutGuide.layoutFrame.width - requestedWidth) > 1 {
            removeBanner()
            failedThisVisit = false
        }
        update()
    }

    private func update() {
        guard let controller else { return }
        guard policy.enabled, policy.visible, !policy.keyboardVisible, !policy.editing,
              isApplicationActive() else {
            removeBanner()
            return
        }
        guard controller.presentedViewController == nil else { return }
        if !policy.consentAllowsAds {
            removeBanner()
            guard !preparing, !failedThisVisit else { return }
            preparing = true
            Task { [weak self] in
                guard let self else { return }
                let allowed = await self.service.prepare(from: controller)
                self.preparing = false
                if !allowed { self.failedThisVisit = true }
                self.update()
            }
            return
        }
        guard policy.canLoad, banner == nil, !failedThisVisit,
              let adUnitID = service.configuration.adUnitID else { return }
        let width = controller.view.safeAreaLayoutGuide.layoutFrame.width
        guard width >= 320 else { return }
        requestedWidth = width
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = controller
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        self.banner = banner
        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor)
        ])
        // Keep the container collapsed until an ad actually loads.
        loadAd(banner)
    }

    private func removeBanner() {
        banner?.delegate = nil
        banner?.removeFromSuperview()
        banner = nil
        impressionRecorded = false
        requestedWidth = 0
        container.isHidden = true
        height?.constant = 0
        adContentBottom?.isActive = false
        fullContentBottom?.isActive = true
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard bannerView === banner, policy.canLoad else { return }
        impressionRecorded = false
        fullContentBottom.isActive = false
        adContentBottom.isActive = true
        height.constant = bannerView.adSize.size.height
        container.isHidden = false
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        guard bannerView === banner else { return }
        analytics.log(.bannerLoadFailed(placement: placement, code: (error as NSError).code))
        failedThisVisit = true
        removeBanner()
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        guard bannerView === banner, policy.canLoad, !container.isHidden, !impressionRecorded else { return }
        impressionRecorded = true
        analytics.log(.bannerImpression(placement: placement))
    }
}
