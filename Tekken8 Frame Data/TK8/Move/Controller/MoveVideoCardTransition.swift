import UIKit

/// A custom full-screen presentation that keeps the source list in place on iOS 17+.
@MainActor
final class MoveVideoCardTransition: NSObject, UIViewControllerTransitioningDelegate {
    private let sourceView: () -> UIView?
    private let reduceMotion: () -> Bool
    private var interaction: UIPercentDrivenInteractiveTransition?
    var didDismiss: (() -> Void)?

    init(sourceView: @escaping () -> UIView?, reduceMotion: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }) {
        self.sourceView = sourceView
        self.reduceMotion = reduceMotion
    }

    func handle(_ pan: UIPanGestureRecognizer, in controller: UIViewController) {
        let width = max(controller.view.bounds.width, 1)
        let progress = min(max(pan.translation(in: controller.view).x / width, 0), 1)
        switch pan.state {
        case .began:
            guard interaction == nil, !controller.isBeingDismissed, !controller.isBeingPresented else { return }
            let interactive = UIPercentDrivenInteractiveTransition()
            interactive.completionCurve = .easeOut
            interaction = interactive
            controller.dismiss(animated: true)
        case .changed:
            interaction?.update(progress)
        case .ended:
            if Self.shouldFinish(progress: progress, velocity: pan.velocity(in: controller.view).x) {
                interaction?.finish()
            } else { interaction?.cancel() }
            interaction = nil
        case .cancelled, .failed:
            interaction?.cancel()
            interaction = nil
        default: break
        }
    }

    static func shouldFinish(progress: CGFloat, velocity: CGFloat) -> Bool {
        // A leftward reversal cancels even after crossing the distance threshold.
        velocity >= 0 && (progress > 0.35 || velocity > 700)
    }

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        MoveVideoCardPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        MoveVideoCardAnimator(presenting: true, sourceView: sourceView, reduceMotion: reduceMotion)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animator = MoveVideoCardAnimator(presenting: false, sourceView: sourceView, reduceMotion: reduceMotion)
        animator.didDismiss = { [weak self] in self?.didDismiss?() }
        return animator
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? { interaction }
}

@MainActor
private final class MoveVideoCardPresentationController: UIPresentationController {
    override var shouldRemovePresentersView: Bool { false }
    override var frameOfPresentedViewInContainerView: CGRect { containerView?.bounds ?? .zero }
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard presentedView?.transform == .identity else { return }
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

@MainActor
private final class MoveVideoCardAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let presenting: Bool
    private let sourceView: () -> UIView?
    private let reduceMotion: () -> Bool
    var didDismiss: (() -> Void)?

    init(presenting: Bool, sourceView: @escaping () -> UIView?, reduceMotion: @escaping () -> Bool) {
        self.presenting = presenting
        self.sourceView = sourceView
        self.reduceMotion = reduceMotion
    }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        reduceMotion() ? 0.18 : 0.30
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = presenting ? .to : .from
        guard let controller = context.viewController(forKey: key),
              let detail = context.view(forKey: presenting ? .to : .from) else {
            context.completeTransition(false)
            return
        }
        let container = context.containerView
        let finalFrame = presenting ? context.finalFrame(for: controller) : detail.frame
        let source = sourceView()
        let originalAlpha = source?.alpha ?? 1
        let sourceFrame = source.map { $0.convert($0.bounds, to: container) }
        let snapshot = source?.snapshotView(afterScreenUpdates: false)
        let reduceMotion = self.reduceMotion() || sourceFrame == nil
        let target = sourceFrame ?? finalFrame
        let originalMask = detail.mask
        // Reveal the card's surface without resizing its text, commands, or video.
        let reveal = UIView()
        reveal.backgroundColor = .white
        reveal.layer.cornerCurve = .continuous
        let cellRevealFrame = target.offsetBy(dx: -finalFrame.minX, dy: -finalFrame.minY)
        if presenting {
            detail.frame = finalFrame
            container.addSubview(detail)
            detail.layoutIfNeeded()
        }
        if !reduceMotion {
            reveal.frame = presenting ? cellRevealFrame : detail.bounds
            reveal.layer.cornerRadius = presenting ? 14 : 0
            detail.mask = reveal
        }
        if let snapshot, !reduceMotion {
            // The source image stays at its original size throughout the crossfade.
            snapshot.frame = target
            snapshot.layer.cornerRadius = 14
            snapshot.clipsToBounds = true
            snapshot.isUserInteractionEnabled = false
            snapshot.alpha = presenting ? 1 : 0
            container.addSubview(snapshot)
            source?.alpha = 0
        }
        if presenting { detail.alpha = 0 }
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            detail.alpha = self.presenting ? 1 : 0
            if !reduceMotion {
                reveal.frame = self.presenting ? detail.bounds : cellRevealFrame
                reveal.layer.cornerRadius = self.presenting ? 0 : 14
                snapshot?.alpha = self.presenting ? 0 : 1
            }
        } completion: { _ in
            let completed = !context.transitionWasCancelled
            snapshot?.removeFromSuperview()
            source?.alpha = originalAlpha
            detail.mask = originalMask
            detail.alpha = 1
            if (self.presenting && !completed) || (!self.presenting && completed) { detail.removeFromSuperview() }
            context.completeTransition(completed)
            if !self.presenting && completed { self.didDismiss?() }
        }
    }
}
