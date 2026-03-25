import SwiftUI

@MainActor
protocol VirtualWidget: AnyObject {
    var refName: String? { get }
    var parent: VirtualWidget? { get }
    func render(_ payload: RenderPayload) -> AnyView
    func toWidget(_ payload: RenderPayload) -> AnyView
}

extension VirtualWidget {
    func empty() -> AnyView {
        AnyView(EmptyView())
    }

    func toWidget(_ payload: RenderPayload) -> AnyView {
        render(payload)
    }
}
