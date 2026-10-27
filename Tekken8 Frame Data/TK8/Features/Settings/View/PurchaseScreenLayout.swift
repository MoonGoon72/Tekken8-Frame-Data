import UIKit

/// 광고 제거 구매 화면과 상세 안내에서 공유하는 UIKit 표시 스타일.
@MainActor
enum PurchaseScreenLayout {
    static func installScroll(in controller: UIViewController) -> UIStackView {
        controller.view.backgroundColor = .tkBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        return stack
    }

    static func label(_ text: String, style: UIFont.TextStyle = .body, secondary: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text.localized()
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = secondary ? .tkSecondaryText : .tkPrimaryText
        return label
    }

    static func configure(_ button: UIButton, title: String, identifier: String,
                          primary: Bool = false, action: @escaping () -> Void) {
        var configuration = primary ? UIButton.Configuration.filled() : .plain()
        configuration.baseBackgroundColor = .tkRed
        configuration.baseForegroundColor = primary ? .white : .tkSecondaryText
        configuration.cornerStyle = .large
        configuration.title = title.localized()
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.contentInsets = NSDirectionalEdgeInsets(top: primary ? 16 : 10, leading: 12,
                                                              bottom: primary ? 16 : 10, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak button] attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: primary ? .headline : .subheadline,
                                                    compatibleWith: button?.traitCollection)
            return attributes
        }
        button.configuration = configuration
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: UIButton, _) in
            button.setNeedsUpdateConfiguration()
            button.invalidateIntrinsicContentSize()
        }
        button.accessibilityIdentifier = identifier
        let height = button.heightAnchor.constraint(greaterThanOrEqualToConstant: primary ? 54 : 44)
        height.priority = UILayoutPriority(999) // Hidden arranged buttons collapse to zero height.
        height.isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    static func showMessage(_ message: String, from controller: UIViewController) {
        guard controller.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Ad removal".localized(), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
        controller.present(alert, animated: true)
    }
}
