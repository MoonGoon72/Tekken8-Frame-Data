import GoogleMobileAds
import UIKit

final class NativeMoveAdCardCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeMoveAdCardCell"

    private let adView = NativeAdView()
    private let sponsoredLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let mediaView = MediaView()
    private let callToActionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        adView.nativeAd = nil
        headlineLabel.text = nil
        bodyLabel.text = nil
        mediaView.mediaContent = nil
        callToActionButton.setTitle(nil, for: .normal)
        callToActionButton.isHidden = true
    }

    func configure(with ad: NativeAd) {
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        bodyLabel.isHidden = ad.body == nil
        mediaView.mediaContent = ad.mediaContent
        callToActionButton.setTitle(ad.callToAction, for: .normal)
        callToActionButton.isHidden = ad.callToAction == nil

        adView.headlineView = headlineLabel
        adView.bodyView = bodyLabel
        adView.mediaView = mediaView
        adView.callToActionView = callToActionButton
        // The SDK owns click handling after this assignment; this cell adds no tap
        // recognizers or custom click behavior.
        adView.nativeAd = ad
    }

    private func setupViews() {
        contentView.backgroundColor = .clear
        adView.backgroundColor = .secondarySystemBackground
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true
        adView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(adView)

        sponsoredLabel.text = NSLocalizedString("Advertisement", comment: "Native ad attribution")
        sponsoredLabel.font = .preferredFont(forTextStyle: .caption2)
        sponsoredLabel.textColor = .secondaryLabel
        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.numberOfLines = 2
        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        mediaView.backgroundColor = .tertiarySystemFill
        mediaView.layer.cornerRadius = 8
        mediaView.clipsToBounds = true
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        callToActionButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        callToActionButton.tintColor = .white
        callToActionButton.backgroundColor = .tkRed
        callToActionButton.layer.cornerRadius = 8
        callToActionButton.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [sponsoredLabel, headlineLabel, bodyLabel, mediaView, callToActionButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(stack)

        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            adView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            adView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            adView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            mediaView.heightAnchor.constraint(equalToConstant: 150),
            callToActionButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}
