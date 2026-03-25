import SwiftUI

@MainActor
final class VWConditionalBuilder: VirtualStatelessWidget<ConditionalBuilderProps> {
    init(
        parentProps: ParentProps?,
        childGroups: [String: [VirtualWidget]]?
    ) {
        super.init(
            props: ConditionalBuilderProps(),
            commonProps: nil,
            parentProps: parentProps,
            childGroups: childGroups,
            parent: nil,
            refName: nil
        )
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        let selected = children?.compactMap { $0 as? VWConditionItem }.first(where: { $0.evaluate(payload) })
        return selected?.child?.toWidget(payload) ?? empty()
    }
}
