import SwiftUI

@MainActor
final class VWOpacity: VirtualStatelessWidget<OpacityProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let resolvedOpacity = payload.eval(props.opacity) ?? 1

        return AnyView(
            Group {
                if let child {
                    child.toWidget(payload)
                } else {
                    EmptyView()
                }
            }
            .opacity(resolvedOpacity)
        )
    }
}
