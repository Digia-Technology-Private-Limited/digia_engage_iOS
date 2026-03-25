import SwiftUI

@MainActor
protocol ChildGroupsAssignable: AnyObject {
    var childGroups: [String: [VirtualWidget]]? { get set }
}

@MainActor
class VirtualStatelessWidget<PropsType>: VirtualLeafStatelessWidget<PropsType>, VirtualContainerWidgetProtocol {
    var childGroups: [String: [VirtualWidget]]?

    init(
        props: PropsType,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        childGroups: [String: [VirtualWidget]]?,
        parent: VirtualWidget?,
        refName: String?
    ) {
        self.childGroups = childGroups
        super.init(
            props: props,
            commonProps: commonProps,
            parentProps: parentProps,
            parent: parent,
            refName: refName
        )
    }

    var child: VirtualWidget? { childOf("child") }
    var children: [VirtualWidget]? { childrenOf("children") }
    var childGroupsValue: [String: [VirtualWidget]]? { childGroups }

    func childOf(_ key: String) -> VirtualWidget? {
        childGroups?[key]?.first
    }

    func childrenOf(_ key: String) -> [VirtualWidget]? {
        childGroups?[key]
    }
}

extension VirtualStatelessWidget: ChildGroupsAssignable {}
