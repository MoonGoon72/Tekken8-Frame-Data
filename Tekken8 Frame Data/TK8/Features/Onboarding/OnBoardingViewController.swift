import UIKit

struct OnboardingFeature {
    let icon: String
    let iconColor: UIColor
    let title: String
    let description: String
}

final class OnboardingViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let features: [OnboardingFeature]
    private let versionText: String
    private let isFirstLaunch: Bool
    private let analytics: AnalyticsClient
    private var isDismissing = false
    private var hasFinished = false
    private var hasRecordedAppearance = false
    var onDismiss: (() -> Void)?

    init(features: [OnboardingFeature], version: String, isFirstLaunch: Bool = false, analytics: AnalyticsClient) {
        self.features = features
        versionText = version
        self.isFirstLaunch = isFirstLaunch
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.detents = isFirstLaunch ? [.large()] : [
            .custom(identifier: .init("new_features")) { context in min(620, context.maximumDetentValue) },
            .large()
        ]
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.preferredCornerRadius = 24
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = "onboarding"
        view.accessibilityViewIsModal = true

        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "onboarding_scroll"
        scroll.alwaysBounceVertical = true
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 24
        content.addArrangedSubview(makeHeader())
        let featureStack = UIStackView(arrangedSubviews: features.map(makeFeatureRow))
        featureStack.axis = .vertical
        featureStack.spacing = 12
        content.addArrangedSubview(featureStack)

        var config = UIButton.Configuration.filled()
        config.title = "Got it".localized()
        config.baseBackgroundColor = .tkRed
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        let button = UIButton(configuration: config)
        button.accessibilityIdentifier = "onboarding_done"
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let footer = UIView()
        footer.backgroundColor = .systemGroupedBackground
        footer.addSubview(button)
        view.addSubview(scroll)
        view.addSubview(footer)
        scroll.addSubview(content)
        [scroll, content, footer, button].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            button.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -16),
            button.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasRecordedAppearance else { return }
        hasRecordedAppearance = true
        analytics.log(.screenViewed(.onboarding))
    }

    private func makeHeader() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)))
        icon.tintColor = .tkRed
        icon.contentMode = .left
        icon.isAccessibilityElement = false
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let title = makeLabel(isFirstLaunch ? "Get to know TK8".localized() : "What's new in TK8".localized(), style: .title1, color: .label)
        title.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        title.accessibilityTraits.insert(.header)
        title.accessibilityIdentifier = "onboarding_title"
        let version = makeLabel(versionText, style: .subheadline, color: .secondaryLabel)
        let subtitle = makeLabel("Explore moves and find the frames you need.".localized(), style: .body, color: .secondaryLabel)
        let header = UIStackView(arrangedSubviews: [icon, version, title, subtitle])
        header.axis = .vertical
        header.spacing = 8
        header.setCustomSpacing(16, after: icon)
        return header
    }

    private func makeFeatureRow(_ feature: OnboardingFeature) -> UIView {
        let row = UIView()
        row.backgroundColor = .secondarySystemGroupedBackground
        row.layer.cornerRadius = 16
        let icon = UIImageView(image: UIImage(systemName: feature.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)))
        icon.tintColor = feature.iconColor
        icon.contentMode = .center
        icon.isAccessibilityElement = false
        let title = makeLabel(feature.title, style: .headline, color: .label)
        title.accessibilityTraits.insert(.header)
        let description = makeLabel(feature.description, style: .subheadline, color: .secondaryLabel)
        let text = UIStackView(arrangedSubviews: [title, description])
        text.axis = .vertical
        text.spacing = 6
        [icon, text].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; row.addSubview($0) }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: row.topAnchor, constant: 18),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            icon.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -18),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            text.topAnchor.constraint(equalTo: row.topAnchor, constant: 18),
            text.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -18)
        ])
        return row
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    @objc private func dismissTapped() {
        guard !isDismissing, !hasFinished else { return }
        isDismissing = true
        dismiss(animated: true) { [weak self] in self?.finishDismissal() }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finishDismissal()
    }

    private func finishDismissal() {
        guard !hasFinished else { return }
        hasFinished = true
        let completion = onDismiss
        onDismiss = nil
        completion?()
    }
}
