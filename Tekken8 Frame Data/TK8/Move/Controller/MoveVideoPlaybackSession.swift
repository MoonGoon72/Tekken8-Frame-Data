import AVFoundation

/// Screen-scoped playback. Neither the list ViewModel nor the repository owns media.
@MainActor
final class MoveVideoPlaybackSession {
    enum State: Equatable { case idle, loading, ready, failed, stopped }

    private(set) var state: State = .idle
    private(set) var player: AVQueuePlayer?
    private(set) var aspectRatio: CGFloat = 16 / 9
    private(set) var allowsAutoplay = true
    private(set) var suspensionCount = 0
    var onChange: (() -> Void)?

    private let reference: MoveVideoReference
    private let provider: MoveVideoPlaybackURLProviding
    private var requestID = UUID()
    private var resolveTask: Task<Void, Never>?
    private var looper: AVPlayerLooper?
    private var queueStatusObservation: NSKeyValueObservation?
    private var looperStatusObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?

    init(reference: MoveVideoReference, provider: MoveVideoPlaybackURLProviding) {
        self.reference = reference
        self.provider = provider
    }

    func load() {
        guard state == .idle else { return }
        state = .loading
        let id = UUID()
        requestID = id
        let reference = reference
        let provider = provider
        onChange?()
        resolveTask = Task { [weak self] in
            do {
                let url = try await provider.playbackURL(for: reference)
                guard !Task.isCancelled, let self, self.requestID == id else { return }
                self.resolveTask = nil
                self.configurePlayer(url: url)
            } catch {
                guard !Task.isCancelled, let self, self.requestID == id else { return }
                self.resolveTask = nil
                self.fail()
            }
        }
    }

    func retry(applicationIsActive: Bool) {
        guard state == .failed else { return }
        stop()
        allowsAutoplay = applicationIsActive
        state = .idle
        load()
    }

    func applicationWillResignActive() {
        suspensionCount += 1
        allowsAutoplay = false
        player?.pause()
    }

    func stop() {
        requestID = UUID()
        resolveTask?.cancel()
        resolveTask = nil
        clearMedia()
        state = .stopped
        onChange?()
    }

    private func configurePlayer(url: URL) {
        let queue = AVQueuePlayer()
        queue.isMuted = true
        player = queue
        let template = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queue, templateItem: template)
        queueStatusObservation = queue.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === observed, observed.status == .failed else { return }
                self.fail()
            }
        }
        looperStatusObservation = looper?.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.looper === observed, observed.status == .failed else { return }
                self.fail()
            }
        }
        currentItemObservation = queue.observe(\.currentItem, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === observed else { return }
                self.observeCurrentItem(observed.currentItem)
            }
        }
        playbackObservation = queue.observe(\.timeControlStatus, options: [.new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === observed, self.state != .failed else { return }
                if observed.timeControlStatus == .playing { self.state = .ready }
                self.onChange?()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            Task { @MainActor [weak self] in
                guard let self, let item, self.player?.currentItem === item else { return }
                self.fail()
            }
        }
        onChange?()
        if allowsAutoplay { queue.play() }
    }

    private func observeCurrentItem(_ item: AVPlayerItem?) {
        statusObservation = nil
        sizeObservation = nil
        guard let item else { return }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                if item.status == .failed { self.fail() }
                else if item.status == .readyToPlay, self.state == .loading {
                    self.state = .ready
                    self.onChange?()
                }
            }
        }
        sizeObservation = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                let size = item.presentationSize
                guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return }
                self.aspectRatio = size.width / size.height
                self.onChange?()
            }
        }
    }

    private func fail() {
        player?.pause()
        state = .failed
        onChange?()
    }

    private func clearMedia() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        queueStatusObservation = nil
        looperStatusObservation = nil
        currentItemObservation = nil
        statusObservation = nil
        sizeObservation = nil
        playbackObservation = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        player?.removeAllItems()
        player = nil
    }

    deinit {
        resolveTask?.cancel()
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        player?.pause()
    }
}
