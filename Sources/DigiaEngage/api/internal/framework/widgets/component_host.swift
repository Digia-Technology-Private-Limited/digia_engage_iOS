import SwiftUI

@MainActor
final class VWComponent: VirtualLeafStatelessWidget<Void> {
    let componentId: String
    let args: [String: JSONValue]
    let registry: VirtualWidgetRegistry

    init(
        componentId: String,
        args: [String: JSONValue],
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        parent: VirtualWidget?,
        refName: String?,
        registry: VirtualWidgetRegistry
    ) {
        self.componentId = componentId
        self.args = args
        self.registry = registry
        super.init(
            props: (),
            commonProps: commonProps,
            parentProps: parentProps,
            parent: parent,
            refName: refName
        )
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        return DUIFactory.shared.createComponent(
            componentId,
            args: args,
            parentStore: payload.localStateStore
        )
    }
}
