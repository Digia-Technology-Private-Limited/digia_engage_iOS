import SwiftUI

@MainActor
final class VWConditionItem: VirtualStatelessWidget<ConditionalItemProps> {
    func evaluate(_ payload: RenderPayload) -> Bool {
        payload.eval(props.condition) ?? false
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        child?.toWidget(payload) ?? empty()
    }
}
