import AVKit
import SwiftUI
import UIKit

@MainActor
final class MoveVideoPlayerViewController: UIViewController, @preconcurrency AVPlayerViewControllerDelegate, UIGestureRecognizerDelegate {
    let playback: MoveVideoPlaybackSession
    private let move: LocalizedMove
    private let playerViewController = AVPlayerViewController()
    private let playerContainer = UIView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let errorContainer = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var errorInsetConstraints: [NSLayoutConstraint] = []
    private var aspectConstraint: NSLayoutConstraint?
    private var edgePan: UIPanGestureRecognizer?
    private var isClosing = false
    private var isVideoFullScreen = false
    var bannerAdHost: BannerAdHost?
    var cardTransition: MoveVideoCardTransition?

    init(move: LocalizedMove, reference: MoveVideoReference, playbackURLProvider: MoveVideoPlaybackURLProviding) {
        self.move = move
        playback = MoveVideoPlaybackSession(reference: reference, provider: playbackURLProvider)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .tkBackground
        configureContent()
        configurePlayer()
        configurePlaybackError()
        configureCloseButton()
        bannerAdHost?.install(in: self)
        view.accessibilityViewIsModal = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(edgeSwiped(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)
        // Let an edge dismissal claim the touch before the detail's scroll view.
        scrollView.panGestureRecognizer.require(toFail: pan)
        edgePan = pan
        playback.onChange = { [weak self] in self?.updatePlaybackUI() }
        NotificationCenter.default.addObserver(self, selector: #selector(pausePlayback), name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UIApplication.shared.applicationState != .active { playback.applicationWillResignActive() }
        playback.load()
        if !isVideoFullScreen, !isClosing { bannerAdHost?.appear() }
        UIAccessibility.post(notification: .screenChanged, argument: closeButton)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bannerAdHost?.disappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bannerAdHost?.layout()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func didFinishDismissal() {
        bannerAdHost?.disappear()
        playback.stop()
        cardTransition = nil
    }

    override func accessibilityPerformEscape() -> Bool {
        closeTapped()
        return true
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.accessibilityIdentifier = "move_detail_scroll"
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        embed(MoveSummaryView(move: move, expanded: true).fixedSize(horizontal: false, vertical: true))
        playerContainer.backgroundColor = .black
        playerContainer.layer.cornerRadius = 12
        playerContainer.clipsToBounds = true
        playerContainer.accessibilityIdentifier = "move_detail_video"
        contentStack.addArrangedSubview(playerContainer)
        if let description = move.description, !description.isEmpty {
            embed(VStack(alignment: .leading, spacing: 8) {
                DescriptionView(description: description, expanded: true)
            }.fixedSize(horizontal: false, vertical: true))
        }
        updateAspectRatio()
    }

    private func embed<Content: View>(_ content: Content) {
        let host = UIHostingController(rootView: content)
        host.sizingOptions = [.intrinsicContentSize]
        host.view.backgroundColor = .clear
        addChild(host)
        contentStack.addArrangedSubview(host.view)
        host.didMove(toParent: self)
    }

    private func configureCloseButton() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 22
        closeButton.accessibilityLabel = "move_video_close".localized()
        closeButton.accessibilityIdentifier = "move_detail_close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configurePlayer() {
        playerViewController.delegate = self
        playerViewController.showsPlaybackControls = true
        playerViewController.allowsPictureInPicturePlayback = false
        playerViewController.videoGravity = .resizeAspect
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(playerViewController)
        playerContainer.addSubview(playerViewController.view)
        NSLayoutConstraint.activate([
            playerViewController.view.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor),
            playerViewController.view.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor)
        ])
        playerViewController.didMove(toParent: self)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.accessibilityLabel = "move_video_loading".localized()
        playerContainer.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: playerContainer.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: playerContainer.centerYAnchor)
        ])
    }

    private func configurePlaybackError() {
        let label = UILabel()
        label.text = "move_video_unavailable".localized()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        let retry = UIButton(type: .system)
        retry.setTitle("move_video_retry".localized(), for: .normal)
        retry.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retry.titleLabel?.adjustsFontForContentSizeCategory = true
        retry.accessibilityIdentifier = "move_detail_retry"
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        errorContainer.axis = .vertical
        errorContainer.alignment = .fill
        errorContainer.spacing = 12
        errorContainer.addArrangedSubview(label)
        errorContainer.addArrangedSubview(retry)
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.isHidden = true
        playerContainer.addSubview(errorContainer)
        NSLayoutConstraint.activate([
            retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            errorContainer.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor, constant: 16),
            errorContainer.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor, constant: -16),
            errorContainer.centerYAnchor.constraint(equalTo: playerContainer.centerYAnchor)
        ])
        errorInsetConstraints = [
            errorContainer.topAnchor.constraint(greaterThanOrEqualTo: playerContainer.topAnchor, constant: 16),
            errorContainer.bottomAnchor.constraint(lessThanOrEqualTo: playerContainer.bottomAnchor, constant: -16)
        ]
        // Hidden error content must not impose a large height on a playing video.
        errorContainer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private func updatePlaybackUI() {
        if playerViewController.player !== playback.player { playerViewController.player = playback.player }
        let failed = playback.state == .failed
        playerViewController.view.isHidden = failed
        errorContainer.isHidden = !failed
        errorInsetConstraints.forEach { $0.isActive = failed }
        if playback.state == .loading { activityIndicator.startAnimating() }
        else { activityIndicator.stopAnimating() }
        updateAspectRatio()
    }

    private func updateAspectRatio() {
        let multiplier = 1 / playback.aspectRatio
        if aspectConstraint?.multiplier == multiplier { return }
        aspectConstraint?.isActive = false
        let constraint = playerContainer.heightAnchor.constraint(equalTo: playerContainer.widthAnchor, multiplier: multiplier)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        aspectConstraint = constraint
    }

    @objc private func closeTapped() {
        guard !isClosing, presentedViewController == nil, !isBeingDismissed else { return }
        isClosing = true
        dismiss(animated: true)
    }

    @objc private func edgeSwiped(_ gesture: UIPanGestureRecognizer) {
        guard presentedViewController == nil else { return }
        cardTransition?.handle(gesture, in: self)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let x = touch.location(in: view).x
        return x >= 0 && x <= 20 && presentedViewController == nil
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let velocity = pan.velocity(in: view)
        return velocity.x > 0 && velocity.x > abs(velocity.y)
    }

    @objc private func retryTapped() {
        playback.retry(applicationIsActive: UIApplication.shared.applicationState == .active)
    }

    @objc private func pausePlayback() { playback.applicationWillResignActive() }

    func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        isVideoFullScreen = true
        edgePan?.isEnabled = false
        bannerAdHost?.disappear()
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self, context.isCancelled else { return }
            self.isVideoFullScreen = false
            self.edgePan?.isEnabled = true
            self.bannerAdHost?.appear()
        }
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        let wasPlaying = (playback.player?.rate ?? 0) > 0
        let suspensionCount = playback.suspensionCount
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self, !context.isCancelled else { return }
            self.isVideoFullScreen = false
            self.edgePan?.isEnabled = true
            if !self.isClosing, !self.isBeingDismissed, self.viewIfLoaded?.window != nil {
                self.bannerAdHost?.appear()
            }
            if wasPlaying, self.playback.suspensionCount == suspensionCount, UIApplication.shared.applicationState == .active {
                self.playback.player?.play()
            } else {
                self.playback.player?.pause()
            }
        }
    }
}
