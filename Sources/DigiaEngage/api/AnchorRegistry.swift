import UIKit

@MainActor
public final class AnchorRegistry {
    public static let shared = AnchorRegistry()
    private init() {}

    private var viewRegistry: [String: WeakBox] = [:]
    private var rectRegistry: [String: CGRect] = [:]
    private var cornerRadii: [String: CGFloat] = [:]

    public func register(key: String, view: UIView, cornerRadius: CGFloat = 0) {
        viewRegistry[key] = WeakBox(view)
        cornerRadii[key] = cornerRadius
    }

    public func register(key: String, rect: CGRect, cornerRadius: CGFloat = 0) {
        rectRegistry[key] = rect
        cornerRadii[key] = cornerRadius
    }

    public func unregister(key: String) {
        viewRegistry.removeValue(forKey: key)
        rectRegistry.removeValue(forKey: key)
        cornerRadii.removeValue(forKey: key)
    }

    public func getView(for key: String) -> UIView? {
        return viewRegistry[key]?.value
    }

    public func getRect(for key: String) -> CGRect? {
        if let rect = rectRegistry[key] { return rect }
        return viewRegistry[key]?.value.map { $0.convert($0.bounds, to: nil) }
    }

    public func getCornerRadius(for key: String) -> CGFloat {
        return cornerRadii[key] ?? 0
    }
}

private final class WeakBox {
    weak var value: UIView?
    init(_ value: UIView) { self.value = value }
}
