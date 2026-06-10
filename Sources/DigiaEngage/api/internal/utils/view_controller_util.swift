import UIKit

@MainActor
enum ViewControllerUtil {
    /// The active foreground window scene, used to host dedicated overlay
    /// windows (e.g. the full-screen inline story).
    static func findWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.keyWindow != nil })
            ?? scenes.first
    }
}
