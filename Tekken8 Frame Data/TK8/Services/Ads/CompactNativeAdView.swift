import GoogleMobileAds
import UIKit

/// A compact footer for image ads; video ads retain a compliant media area.
@MainActor
final class CompactNativeAdView: NativeAdView {
    private let icon = UIImageView()
    private let headline = UILabel()
    private let attribution = UILabel()
    private let action = UIButton(type: .system)
    private let video = MediaView()
    private let row = UIStackView()
    private let text = UIStackView()
    private var textWidth: NSLayoutConstraint!
    private var actionHeight: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .tkSurface
        layer.cornerRadius = 12

        attribution.text = NSLocalizedString("Advertisement", comment: "Native ad attribution")
        attribution.font = .preferredFont(forTextStyle: .caption2)
        attribution.textColor = .tkSecondaryText
        attribution.adjustsFontForContentSizeCategory = true
        attribution.numberOfLines = 0
        attribution.heightAnchor.constraint(greaterThanOrEqualToConstant: 15).isActive = true
        headline.font = .preferredFont(forTextStyle: .subheadline)
        headline.textColor = .tkPrimaryText
        headline.adjustsFontForContentSizeCategory = true
        headline.numberOfLines = 0

        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 8
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        video.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            video.widthAnchor.constraint(equalToConstant: 120),
            video.heightAnchor.constraint(equalToConstant: 120)
        ])
        (icon.constraints + video.constraints).forEach { $0.priority = .defaultHigh }

        action.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        action.titleLabel?.adjustsFontForContentSizeCategory = true
        action.titleLabel?.numberOfLines = 0
        action.titleLabel?.textAlignment = .center
        action.tintColor = .white
        action.backgroundColor = .tkRed
        action.layer.cornerRadius = 8
        action.isUserInteractionEnabled = false
        action.translatesAutoresizingMaskIntoConstraints = false
        action.widthAnchor.constraint(equalToConstant: 88).isActive = true
        actionHeight = action.heightAnchor.constraint(equalToConstant: 36)
        actionHeight.priority = .defaultHigh
        actionHeight.isActive = true
        [attribution, headline].forEach(text.addArrangedSubview)
        text.alignment = .leading
        headline.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        text.axis = .vertical
        text.spacing = 4
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        [video, icon, text, action].forEach(row.addArrangedSubview)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        textWidth = text.widthAnchor.constraint(equalTo: row.widthAnchor)
        // Leave the top-right corner unobstructed for the SDK's AdChoices overlay.
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68)
        ])
        headlineView = headline
        iconView = icon
        callToActionView = action
        mediaView = video
        video.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with ad: NativeAd) {
        headline.text = ad.headline
        icon.image = ad.icon?.image
        // Video already supplies the required main asset; keep any supplied icon visible.
        icon.isHidden = ad.icon == nil
        action.setTitle(ad.callToAction, for: .normal)
        action.isHidden = ad.callToAction == nil
        video.isHidden = !ad.mediaContent.hasVideoContent
        video.mediaContent = ad.mediaContent.hasVideoContent ? ad.mediaContent : nil
        // Video stays beside a column of assets rather than inflating the footer
        // to the full width of a media card. Large text uses a vertical layout.
        row.arrangedSubviews.forEach { row.removeArrangedSubview($0); $0.removeFromSuperview() }
        [icon, action].forEach { text.removeArrangedSubview($0); $0.removeFromSuperview() }
        if ad.mediaContent.hasVideoContent {
            [icon, action].forEach(text.addArrangedSubview)
            [video, text].forEach(row.addArrangedSubview)
        } else {
            [icon, text, action].forEach(row.addArrangedSubview)
        }
        row.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        row.alignment = .center
        textWidth.isActive = row.axis == .vertical
        nativeAd = ad
    }

    func requiredHeight(for width: CGFloat) -> CGFloat {
        headline.preferredMaxLayoutWidth = row.axis == .vertical ? width - 20 : width - 20 - (video.isHidden ? (icon.isHidden ? 0 : 56) + (action.isHidden ? 0 : 96) : 128)
        actionHeight.constant = max(36, (action.titleLabel?.sizeThatFits(CGSize(width: 72, height: CGFloat.greatestFiniteMagnitude)).height ?? 0) + 16)
        return systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                               withHorizontalFittingPriority: .required,
                               verticalFittingPriority: .fittingSizeLevel).height
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let nativeAd { configure(with: nativeAd) }
    }
}
