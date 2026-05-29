import SwiftUI
import UIKit

/// Re-enables the interactive pop gesture when the navigation bar back button is hidden.
///
/// Follows the same UIKit hook as [this gist](https://gist.github.com/Chronos2500/0a2b653fe0a1150c2023adc60797dc12) and
/// [Yasushi Oh’s article](https://medium.com/@calen0909/swiftui-navigation-enable-swipe-back-gesture-while-hiding-back-button-navigate-in-functions-13028424600c):
/// the representable’s controller uses `parent?.navigationController` (critical) and becomes the pop gesture’s delegate.
///
/// Apply **once** to the **root** view inside ``NavigationStack`` (see ``DigiaNavigationView``), not on the stack wrapper.
struct DigiaSmartSwipeBackControl: View {
    @ObservedObject private var navigation = SDKInstance.shared.navigationController

    var body: some View {
        DigiaSwipeBackSetupRepresentable(allowsSwipeBack: navigation.allowsSwipeBack)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Enables the native edge swipe to pop when `.navigationBarBackButtonHidden(true)` is used on pushed pages.
    func digiaSmartSwipeBackControl() -> some View {
        background(DigiaSmartSwipeBackControl())
    }
}

// MARK: - UIKit bridge

private struct DigiaSwipeBackSetupRepresentable: UIViewControllerRepresentable {
    var allowsSwipeBack: Bool

    func makeUIViewController(context: Context) -> DigiaSwipeBackAnchorViewController {
        let vc = DigiaSwipeBackAnchorViewController()
        vc.allowsSwipeBack = allowsSwipeBack
        return vc
    }

    func updateUIViewController(_ uiViewController: DigiaSwipeBackAnchorViewController, context: Context) {
        uiViewController.allowsSwipeBack = allowsSwipeBack
    }
}

/// Host that forwards pop-gesture delegate to itself so the system can begin the interactive pop
/// even when the back button is hidden (see gist / Medium article).
private final class DigiaSwipeBackAnchorViewController: UIViewController, UIGestureRecognizerDelegate {
    var allowsSwipeBack: Bool = true
    private weak var observedNavigationController: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        bindPopGesture(usingParent: parent)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // SwiftUI sometimes wires the parent after `didMove`; retry once the hierarchy is stable.
        if observedNavigationController == nil {
            bindPopGesture(usingParent: parent)
        }
        DispatchQueue.main.async { [weak self] in
            self?.bindPopGesture(usingParent: self?.parent)
        }
    }

    private func bindPopGesture(usingParent parent: UIViewController?) {
        // Critical: use the *parent*’s `navigationController`, same as the working gist — walking from `self` often fails.
        let nav = parent?.navigationController
            ?? navigationController
            ?? findNavigationControllerByWalkingAncestors(from: parent)
            ?? findNavigationControllerInWindowHierarchy()
        guard let nav else { return }
        observedNavigationController = nav
        applyPopGestureDelegate(on: nav)
    }

    private func applyPopGestureDelegate(on nav: UINavigationController) {
        nav.interactivePopGestureRecognizer?.delegate = self
        nav.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func findNavigationControllerByWalkingAncestors(from start: UIViewController?) -> UINavigationController? {
        var current: UIViewController? = start
        while let viewController = current {
            if let nav = viewController as? UINavigationController { return nav }
            if let nav = viewController.navigationController { return nav }
            current = viewController.parent
        }
        return nil
    }

    private func findNavigationControllerInWindowHierarchy() -> UINavigationController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
        else { return nil }
        return findNavigationControllerRecursively(in: root)
    }

    private func findNavigationControllerRecursively(in vc: UIViewController) -> UINavigationController? {
        if let nav = vc as? UINavigationController { return nav }
        if let nav = vc.navigationController { return nav }
        for child in vc.children {
            if let found = findNavigationControllerRecursively(in: child) { return found }
        }
        if let presented = vc.presentedViewController {
            return findNavigationControllerRecursively(in: presented)
        }
        return nil
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = observedNavigationController ?? parent?.navigationController ?? navigationController else {
            return false
        }
        guard nav.viewControllers.count > 1 else { return false }
        return allowsSwipeBack
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Helps when a scroll view is the first responder on the pushed page.
        true
    }
}
