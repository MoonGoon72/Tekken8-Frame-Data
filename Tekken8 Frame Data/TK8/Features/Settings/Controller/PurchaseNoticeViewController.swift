import Combine
import UIKit

/// 혜택과 실제 가격을 먼저 보여주는 광고 제거 구매 화면.
@MainActor
final class PurchaseNoticeViewController: UIViewController {
    private let viewModel: SettingsPurchaseViewModel
    private let contact: (UIViewController) -> Void
    private var subscriptions = Set<AnyCancellable>()
    private let purchaseButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let statusLabel = PurchaseScreenLayout.label("", style: .subheadline, secondary: true)
    private let headline = PurchaseScreenLayout.label("Focus on moves, without ads.", style: .title2)
    private let summary = PurchaseScreenLayout.label("Remove banner ads and ads in the move list.", style: .subheadline, secondary: true)
    private let paymentNote = PurchaseScreenLayout.label("One-time purchase. No automatic renewal.", style: .footnote, secondary: true)
    private let icon = UIImageView()

    init(viewModel: SettingsPurchaseViewModel, contact: @escaping (UIViewController) -> Void) {
        self.viewModel = viewModel
        self.contact = contact
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ad removal".localized()
        navigationItem.largeTitleDisplayMode = .never
        let stack = PurchaseScreenLayout.installScroll(in: self)
        stack.addArrangedSubview(makeBenefitCard())
        statusLabel.textAlignment = .center
        statusLabel.accessibilityTraits.insert(.updatesFrequently)
        statusLabel.accessibilityIdentifier = "ad_removal_status"
        stack.addArrangedSubview(statusLabel)
        PurchaseScreenLayout.configure(purchaseButton, title: "Ad removal", identifier: "ad_removal_buy", primary: true) { [weak self] in
            guard let self, self.viewModel.canPurchase else { return }
            Task { await self.viewModel.buy() }
        }
        stack.addArrangedSubview(purchaseButton)
        paymentNote.textAlignment = .center
        stack.addArrangedSubview(paymentNote)
        PurchaseScreenLayout.configure(retryButton, title: "Check purchases and price again", identifier: "ad_removal_retry") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.prepare() }
        }
        stack.addArrangedSubview(retryButton)
        let secondaryActions = UIStackView()
        secondaryActions.axis = .vertical
        secondaryActions.spacing = 0
        PurchaseScreenLayout.configure(restoreButton, title: "Restore purchases", identifier: "ad_removal_restore") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.restore() }
        }
        secondaryActions.addArrangedSubview(restoreButton)
        let information = UIButton(type: .system)
        PurchaseScreenLayout.configure(information, title: "Purchase and refund information", identifier: "ad_removal_information") { [weak self] in
            guard let self, let navigationController = self.navigationController,
                  navigationController.topViewController === self else { return }
            let details = PurchaseInformationViewController(contact: self.contact)
            navigationController.pushViewController(details, animated: true)
        }
        secondaryActions.addArrangedSubview(information)
        stack.addArrangedSubview(secondaryActions)
        viewModel.$state.sink { [weak self] _ in
            // @Published는 대입 전에 알린다. 다음 메인 큐에서 최신 값을 읽는다.
            DispatchQueue.main.async { self?.updateState() }
        }.store(in: &subscriptions)
        viewModel.$isPreparing.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateState() }
        }.store(in: &subscriptions)
        viewModel.$message.compactMap { $0 }.sink { [weak self] _ in
            DispatchQueue.main.async { self?.presentPendingPurchaseMessage() }
        }.store(in: &subscriptions)
        updateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPendingPurchaseMessage()
        Task { await viewModel.prepare() }
    }

    private func makeBenefitCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .tkSurface
        card.layer.cornerRadius = 20
        let content = UIStackView(arrangedSubviews: [icon, headline, summary])
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        headline.textAlignment = .center
        headline.accessibilityTraits.insert(.header)
        summary.textAlignment = .center
        icon.tintColor = .tkRed
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            icon.heightAnchor.constraint(equalToConstant: 44)
        ])
        return card
    }

    private func updateState() {
        let state = viewModel.state
        let purchased = state.entitlement == .adFree
        headline.text = (purchased ? "Ads removed" : "Focus on moves, without ads.").localized()
        summary.text = (purchased ? "Banner and move list ads have been removed." : "Remove banner ads and ads in the move list.").localized()
        icon.image = UIImage(systemName: purchased ? "checkmark.circle.fill" : "sparkles")
        icon.tintColor = purchased ? .systemGreen : .tkRed
        paymentNote.isHidden = purchased
        statusLabel.text = viewModel.purchaseDetail
        statusLabel.isHidden = purchased || (!viewModel.isPreparing && state.entitlement == .notPurchased &&
            state.displayPrice != nil && !state.isBusy && !state.pending)
        purchaseButton.configuration?.title = state.displayPrice.map {
            String(format: "Remove ads for %@".localized(), $0)
        } ?? (viewModel.isPreparing || state.entitlement == .checking ? "Loading price…" : "Ad removal").localized()
        purchaseButton.isEnabled = viewModel.canPurchase
        purchaseButton.isHidden = purchased
        restoreButton.isEnabled = !state.isBusy && !viewModel.isPreparing
        retryButton.isHidden = !viewModel.shouldOfferRetry
    }

    private func presentPendingPurchaseMessage() {
        guard navigationController?.topViewController === self,
              viewIfLoaded?.window != nil, presentedViewController == nil,
              !isBeingDismissed, let message = viewModel.message else { return }
        PurchaseScreenLayout.showMessage(message, from: self)
        viewModel.clearMessage()
    }
}
