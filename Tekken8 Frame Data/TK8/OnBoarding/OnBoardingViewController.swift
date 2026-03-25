//
//  OnBoardingViewController.swift
//  TK8
//

import Foundation
import UIKit

struct OnboardingFeature {
    let icon: String        // SF Symbol name
    let iconColor: UIColor
    let title: String
    let description: String
}

final class OnboardingViewController: UIViewController {

    private let features: [OnboardingFeature]
    private let versionText: String

    init(features: [OnboardingFeature], version: String) {
        self.features = features
        self.versionText = version
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Views

    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.1, green: 0.18, blue: 0.25, alpha: 1)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        view.clipsToBounds = true
        return view
    }()

    private let appIconView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.15)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.25).cgColor
        return view
    }()

    private let appIconImage: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let view = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: config))
        view.tintColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.8)
        view.contentMode = .center
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "What's new in TK8"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.4)
        label.textAlignment = .center
        return label
    }()

    private let featureStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private let dismissButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.9)
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)

        let button = UIButton(configuration: config)
        button.setTitle("Get Started", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupLayouts()

        versionLabel.text = versionText
        features.forEach { feature in
            featureStackView.addArrangedSubview(makeFeatureRow(feature))
        }

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dimView.addGestureRecognizer(tap)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 등장 애니메이션
        containerView.transform = CGAffineTransform(translationX: 0, y: 40)
        containerView.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        }
    }

    // MARK: - Private

    private func makeFeatureRow(_ feature: OnboardingFeature) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        row.layer.cornerRadius = 12

        let iconContainer = UIView()
        iconContainer.backgroundColor = feature.iconColor.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 10

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconImage = UIImageView(image: UIImage(systemName: feature.icon, withConfiguration: config))
        iconImage.tintColor = feature.iconColor
        iconImage.contentMode = .center

        let titleLabel = UILabel()
        titleLabel.text = feature.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white

        let descLabel = UILabel()
        descLabel.text = feature.description
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        descLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        [iconContainer, iconImage, textStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        row.addSubview(iconContainer)
        iconContainer.addSubview(iconImage)
        row.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            iconContainer.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),

            iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
        ])

        return row
    }

    @objc private func dismissTapped() {
        UIView.animate(withDuration: 0.25, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: 30)
            self.containerView.alpha = 0
            self.dimView.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }

    @objc private func dimTapped() {
        dismissTapped()
    }

    // MARK: - Setup

    private func setupViews() {
        view.addSubview(dimView)
        view.addSubview(containerView)

        containerView.addSubview(appIconView)
        appIconView.addSubview(appIconImage)
        containerView.addSubview(titleLabel)
        containerView.addSubview(versionLabel)
        containerView.addSubview(featureStackView)
        containerView.addSubview(dismissButton)
    }

    private func setupLayouts() {
        [dimView, containerView, appIconView, appIconImage,
         titleLabel, versionLabel, featureStackView, dismissButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            appIconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 28),
            appIconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 56),
            appIconView.heightAnchor.constraint(equalToConstant: 56),

            appIconImage.centerXAnchor.constraint(equalTo: appIconView.centerXAnchor),
            appIconImage.centerYAnchor.constraint(equalTo: appIconView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            versionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            featureStackView.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 20),
            featureStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            featureStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            dismissButton.topAnchor.constraint(equalTo: featureStackView.bottomAnchor, constant: 24),
            dismissButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            dismissButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            dismissButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
        ])
    }
}
