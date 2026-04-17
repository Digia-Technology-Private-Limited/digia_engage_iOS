import SwiftUI
import UIKit

@MainActor
enum ViewControllerUtil {
    private static var rootViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let vc = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow?.rootViewController {
            return vc
        }
        if let vc = scenes.compactMap({ $0.keyWindow }).first?.rootViewController {
            return vc
        }
        return scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController
    }

    static func topViewController(base: UIViewController? = rootViewController) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    static func present(_ controller: UIViewController, animated: Bool = true) {
        topViewController()?.present(controller, animated: animated)
    }

    static func dismissPresented(animated: Bool = true, completion: (() -> Void)? = nil) {
        topViewController()?.dismiss(animated: animated, completion: completion)
    }

    static func popNavigation(animated: Bool = true) {
        if let navigation = topViewController()?.navigationController {
            navigation.popViewController(animated: animated)
        } else {
            topViewController()?.dismiss(animated: animated)
        }
    }

    static func popToRoot(animated: Bool = true) {
        if let navigation = topViewController()?.navigationController {
            navigation.popToRootViewController(animated: animated)
        } else {
            topViewController()?.dismiss(animated: animated)
        }
    }
}
