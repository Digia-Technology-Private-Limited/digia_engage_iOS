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
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableIfNeeded()
    }

    func enableIfNeeded() {
        NavigationUtil.enableInteractivePopGestureIfNeeded(for: navigationController)
    }
}

extension View {
    @ViewBuilder
    func digiaKeepSwipeBackGestureEnabled() -> some View {
        self.background(DigiaInteractivePopGestureHost().frame(width: 0, height: 0))
    }
}
