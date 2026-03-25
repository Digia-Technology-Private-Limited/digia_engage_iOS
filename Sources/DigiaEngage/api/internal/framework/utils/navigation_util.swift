import Foundation
import SwiftUI
import UIKit

enum NavigationUtil {
    static func normalizedRoute(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func enableInteractivePopGestureIfNeeded(for navigationController: UINavigationController?) {
        guard let navigationController, navigationController.viewControllers.count > 1 else { return }
        guard let popGesture = navigationController.interactivePopGestureRecognizer else { return }
        popGesture.isEnabled = true
        popGesture.delegate = nil
    }
}

private struct DigiaInteractivePopGestureHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DigiaInteractivePopGestureHostController {
        DigiaInteractivePopGestureHostController()
    }

    func updateUIViewController(_ uiViewController: DigiaInteractivePopGestureHostController, context: Context) {
        uiViewController.enableIfNeeded()
    }
}

private final class DigiaInteractivePopGestureHostController: UIViewController {
    /// Gesture attached to the NavigationController's view when we are the root page,
    /// so a left-edge swipe dismisses the entire Digia navigation overlay.
    private weak var rootEdgeGesture: UIScreenEdgePanGestureRecognizer?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeRootEdgeGestureIfPresent()
    }

    func enableIfNeeded() {
        guard let nav = navigationController else { return }
        if nav.viewControllers.count > 1 {
            // Deeper page: restore the native interactive-pop gesture and drop the root one.
            removeRootEdgeGestureIfPresent()
            NavigationUtil.enableInteractivePopGestureIfNeeded(for: nav)
        } else {
            // Root page of the Digia overlay: native pop gesture has nothing to pop to,
            // so attach a custom left-edge gesture that dismisses the entire overlay.
            addRootEdgeGestureIfNeeded(to: nav.view)
        }
    }

    // MARK: - Root-page edge gesture

    private func addRootEdgeGestureIfNeeded(to view: UIView) {
        guard rootEdgeGesture == nil else { return }
        let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleRootEdgePan(_:)))
        gesture.edges = .left
        view.addGestureRecognizer(gesture)
        rootEdgeGesture = gesture
    }

    private func removeRootEdgeGestureIfPresent() {
        guard let gesture = rootEdgeGesture else { return }
        gesture.view?.removeGestureRecognizer(gesture)
        rootEdgeGesture = nil
    }

    @objc private func handleRootEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .recognized else { return }
        Task { @MainActor in
            SDKInstance.shared.navigationController.pop()
        }
    }
}

extension View {
    @ViewBuilder
    func digiaKeepSwipeBackGestureEnabled() -> some View {
        self.background(DigiaInteractivePopGestureHost().frame(width: 0, height: 0))
    }
}
