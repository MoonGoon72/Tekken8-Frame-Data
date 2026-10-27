import UIKit

/// 구매 화면의 더보기에서 여는 구매 적용·복원·환불·약관 안내.
@MainActor
final class PurchaseInformationViewController: UIViewController {
    private let contact: (UIViewController) -> Void

    init(contact: @escaping (UIViewController) -> Void) {
        self.contact = contact
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Purchase and refund information".localized()
        navigationItem.largeTitleDisplayMode = .never
        let stack = PurchaseScreenLayout.installScroll(in: self)
        addSection("Purchase activation", paragraphs: [Self.paragraphs[0], Self.paragraphs[1]], to: stack)
        addSection("Restoring on another device", paragraphs: [Self.paragraphs[2]], to: stack)
        addSection("Refunds", paragraphs: [Self.paragraphs[3], Self.paragraphs[4]], to: stack)
        addLink("Request a refund from Apple", "https://reportaproblem.apple.com/",
                identifier: "purchase_information_refund", to: stack)
        addLink("Apple refund guidance", "https://support.apple.com/118223", to: stack)
        addSection("Terms and support", paragraphs: [], to: stack)
        addLink("Apple Media Services terms", "https://www.apple.com/legal/internet-services/itunes/", to: stack)
        addLink("Apple standard license agreement", "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/", to: stack)
        addLink("Developer information on the App Store", "https://apps.apple.com/app/id6745224754", to: stack)
        let contactButton = UIButton(type: .system)
        PurchaseScreenLayout.configure(contactButton, title: "Contact developer", identifier: "purchase_information_contact") { [weak self] in
            guard let self else { return }
            self.contact(self)
        }
        stack.addArrangedSubview(contactButton)
    }

    private func addSection(_ title: String, paragraphs: [String], to stack: UIStackView) {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 12
        let heading = PurchaseScreenLayout.label(title, style: .headline)
        heading.accessibilityTraits.insert(.header)
        section.addArrangedSubview(heading)
        for text in paragraphs {
            section.addArrangedSubview(PurchaseScreenLayout.label(text, style: .subheadline, secondary: true))
        }
        stack.addArrangedSubview(section)
        stack.setCustomSpacing(24, after: section)
    }

    private func addLink(_ title: String, _ address: String, identifier: String = "", to stack: UIStackView) {
        let button = UIButton(type: .system)
        PurchaseScreenLayout.configure(button, title: title, identifier: identifier) { [weak self] in
            guard let self, let url = URL(string: address) else { return }
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                guard !opened else { return }
                DispatchQueue.main.async {
                    guard let self else { return }
                    PurchaseScreenLayout.showMessage("Unable to open the page. Please try again.".localized(), from: self)
                }
            }
        }
        stack.addArrangedSubview(button)
    }

    private static let paragraphs = [
        "Removes banner ads and native ads in the move list in this app. This is not a subscription and does not renew automatically. Check the price on the purchase button and Apple's payment confirmation screen.",
        "Ad removal is enabled once the purchase is completed and verified. A pending or failed payment is not treated as a completed purchase. If ad removal is not enabled, try Restore Purchases or contact the developer.",
        "Purchases can be restored on supported devices using the same App Store purchase account. Transfer to another Apple Account and Family Sharing are not supported. An internet connection may be required to purchase or restore.",
        "You can request a refund through Apple's Report a Problem page. Refund eligibility and processing are subject to applicable law and Apple's procedures; submitting a request does not guarantee approval. Ad removal is disabled if a refund is approved and the purchase entitlement is revoked. Contact the developer if the purchased feature does not work as described.",
        "Rights to cancel purchases by minors made without their legal representative's consent apply where provided by applicable law. This notice does not limit statutory consumer rights, including withdrawal and refund rights."
    ]
}
