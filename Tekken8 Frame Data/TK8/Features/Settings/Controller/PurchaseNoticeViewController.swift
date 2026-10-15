import Combine
import UIKit

/// 구매 전후 모두 제공 범위와 복원·환불 안내를 확인할 수 있는 화면이다.
@MainActor
final class PurchaseNoticeViewController: UIViewController {
    private let viewModel: SettingsPurchaseViewModel
    private let contact: (UIViewController) -> Void
    private var subscriptions = Set<AnyCancellable>()
    private let purchaseButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    init(viewModel: SettingsPurchaseViewModel, contact: @escaping (UIViewController) -> Void) {
        self.viewModel = viewModel
        self.contact = contact
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Purchase information".localized()
        view.backgroundColor = .tkBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        stack.addArrangedSubview(label("Remove Ads · One-time purchase", style: .title2))
        for text in Self.paragraphs { stack.addArrangedSubview(label(text)) }
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .white
        statusLabel.accessibilityTraits.insert(.updatesFrequently)
        stack.addArrangedSubview(statusLabel)
        configure(purchaseButton, title: "Ad removal") { [weak self] in
            guard let self, self.viewModel.canPurchase else { return }
            Task { await self.viewModel.buy() }
        }
        configure(restoreButton, title: "Restore purchases") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.restore() }
        }
        configure(retryButton, title: "Check purchases and price again") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.prepare() }
        }
        [purchaseButton, restoreButton, retryButton].forEach { stack.addArrangedSubview($0) }
        addLink("Request a refund from Apple", "https://reportaproblem.apple.com/", to: stack)
        addLink("Apple refund guidance", "https://support.apple.com/118223", to: stack)
        addLink("Apple Media Services terms", "https://www.apple.com/legal/internet-services/itunes/", to: stack)
        addLink("Apple standard license agreement", "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/", to: stack)
        addLink("Developer information on the App Store", "https://apps.apple.com/app/id6745224754", to: stack)
        let contactButton = UIButton(type: .system)
        configure(contactButton, title: "Contact developer") { [weak self] in
            guard let self else { return }
            self.contact(self)
        }
        stack.addArrangedSubview(contactButton)
        viewModel.$state.sink { [weak self] _ in
            // @Published는 프로퍼티에 값이 대입되기 전에 변경을 알린다.
            DispatchQueue.main.async { self?.updateState() }
        }.store(in: &subscriptions)
        viewModel.$message.compactMap { $0 }.sink { [weak self] _ in
            // 다른 구독자가 이미 메시지를 처리했을 수 있으므로 현재 값을 다시 읽는다.
            DispatchQueue.main.async { self?.presentPendingPurchaseMessage() }
        }.store(in: &subscriptions)
        updateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPendingPurchaseMessage()
        Task { await viewModel.prepare() }
    }

    private func presentPendingPurchaseMessage() {
        guard navigationController?.topViewController === self,
              viewIfLoaded?.window != nil, presentedViewController == nil,
              !isBeingDismissed, let message = viewModel.message else { return }
        showMessage(message)
        viewModel.clearMessage()
    }

    private func updateState() {
        statusLabel.text = viewModel.purchaseDetail
        let title = viewModel.state.displayPrice.map {
            String(format: "Buy for %@".localized(), $0)
        } ?? "Ad removal".localized()
        purchaseButton.configuration?.title = title
        purchaseButton.isEnabled = viewModel.canPurchase
        purchaseButton.isHidden = viewModel.state.entitlement == .adFree
        restoreButton.isEnabled = !viewModel.state.isBusy
        retryButton.isEnabled = !viewModel.state.isBusy
    }

    private func label(_ text: String, style: UIFont.TextStyle = .body) -> UILabel {
        let label = UILabel()
        label.text = text.localized()
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .white
        return label
    }

    private func configure(_ button: UIButton, title: String, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.tinted()
        configuration.baseForegroundColor = .white
        configuration.title = title.localized()
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .body)
            return attributes
        }
        button.configuration = configuration
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func addLink(_ title: String, _ address: String, to stack: UIStackView) {
        let button = UIButton(type: .system)
        configure(button, title: title) { [weak self] in
            guard let url = URL(string: address) else { return }
            UIApplication.shared.open(url, options: [:]) { opened in
                guard !opened else { return }
                DispatchQueue.main.async {
                    self?.showMessage("Unable to open the page. Please try again.".localized())
                }
            }
        }
        stack.addArrangedSubview(button)
    }

    private func showMessage(_ message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Ad removal".localized(), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
        present(alert, animated: true)
    }

    private static let paragraphs = [
        "Removes banner ads and native ads in the move list in this app. This is not a subscription and does not renew automatically. Check the price on the purchase button and Apple's payment confirmation screen.",
        "Ad removal is enabled once the purchase is completed and verified. A pending or failed payment is not treated as a completed purchase. If ad removal is not enabled, try Restore Purchases or contact the developer.",
        "Purchases can be restored on supported devices using the same App Store purchase account. Transfer to another Apple Account and Family Sharing are not supported. An internet connection may be required to purchase or restore.",
        "You can request a refund through Apple's Report a Problem page. Refund eligibility and processing are subject to applicable law and Apple's procedures; submitting a request does not guarantee approval. Ad removal is disabled if a refund is approved and the purchase entitlement is revoked. Contact the developer if the purchased feature does not work as described.",
        "Rights to cancel purchases by minors made without their legal representative's consent apply where provided by applicable law. This notice does not limit statutory consumer rights, including withdrawal and refund rights."
    ]
}
