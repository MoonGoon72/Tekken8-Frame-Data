import UIKit

/// 광고 SDK 소재와 분리된 앱 소유의 안내 영역.
final class AdRemovalNoticeView: UIView {
    private let messageAndAction = UIStackView()

    init(onLearnMore: @escaping () -> Void, onClose: @escaping () -> Void) {
        super.init(frame: .zero)
        accessibilityIdentifier = "ad_removal_notice"
        backgroundColor = .tkSurface
        clipsToBounds = true

        let message = UILabel()
        message.text = "You can use the app without ads.".localized()
        message.accessibilityIdentifier = "ad_removal_notice_message"
        message.font = .preferredFont(forTextStyle: .subheadline)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        message.textColor = .tkPrimaryText

        let learnMore = UIButton(type: .system)
        learnMore.setTitle("Learn more".localized(), for: .normal)
        learnMore.accessibilityIdentifier = "ad_removal_notice_learn_more"
        learnMore.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        learnMore.titleLabel?.adjustsFontForContentSizeCategory = true
        learnMore.titleLabel?.numberOfLines = 0
        learnMore.setContentCompressionResistancePriority(.required, for: .horizontal)
        learnMore.addAction(UIAction { _ in onLearnMore() }, for: .touchUpInside)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.accessibilityLabel = "Close".localized()
        close.accessibilityIdentifier = "ad_removal_notice_close"
        close.tintColor = .tkSecondaryText
        close.addAction(UIAction { _ in onClose() }, for: .touchUpInside)

        messageAndAction.axis = .horizontal
        messageAndAction.alignment = .center
        messageAndAction.spacing = 8
        messageAndAction.addArrangedSubview(message)
        messageAndAction.addArrangedSubview(learnMore)

        let row = UIStackView(arrangedSubviews: [messageAndAction, close])
        row.alignment = .top
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        // A hidden arranged subview is constrained to zero height by UIStackView.
        // Let its bottom padding yield while hidden, without breaking button constraints.
        let bottom = row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        bottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8), bottom,
            learnMore.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            learnMore.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44),
            close.widthAnchor.constraint(equalToConstant: 44)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: AdRemovalNoticeView, _) in
            self.updateArrangement()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        updateArrangement()
        super.layoutSubviews()
    }

    private func updateArrangement() {
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory || bounds.width < 350
        messageAndAction.axis = vertical ? .vertical : .horizontal
        messageAndAction.alignment = vertical ? .leading : .center
    }
}
