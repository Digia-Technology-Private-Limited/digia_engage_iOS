import SwiftUI

@MainActor
class VirtualLeafStatelessWidget<PropsType>: VirtualWidget, VirtualLeafStatelessWidgetProtocol, ParentAssignableVirtualWidget {
    let props: PropsType
    let commonProps: CommonProps?
    let parentProps: ParentProps?
    let refName: String?
    weak var parent: VirtualWidget?

    var parentPropsValue: ParentProps? { parentProps }
    var commonAlignValue: String? { commonProps?.align }

    init(
        props: PropsType,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        parent: VirtualWidget?,
        refName: String?
    ) {
        self.props = props
        self.commonProps = commonProps
        self.parentProps = parentProps
        self.parent = parent
        self.refName = refName
    }

    func render(_ payload: RenderPayload) -> AnyView {
        empty()
    }

    func toWidget(_ payload: RenderPayload) -> AnyView {
        toWidget(payload, skipContainerSizing: false)
    }

    func toWidget(_ payload: RenderPayload, skipContainerSizing: Bool) -> AnyView {
        if payload.eval(commonProps?.visibility) == false {
            return empty()
        }

        var current = render(payload)
        current = WidgetUtil.wrapInContainer(
            payload: payload,
            style: commonProps?.style,
            child: current,
            skipSizing: skipContainerSizing
        )
        current = WidgetUtil.wrapInAlign(value: commonProps?.align, child: current)
        current = WidgetUtil.wrapInTapGesture(payload: payload, actionFlow: commonProps?.onClick, child: current)
        current = WidgetUtil.applyMargin(style: commonProps?.style, child: current)
        return current
    }
}
