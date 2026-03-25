@MainActor
protocol VirtualLeafStatelessWidgetProtocol: AnyObject {
    var parentPropsValue: ParentProps? { get }
    var commonAlignValue: String? { get }
}

@MainActor
protocol ParentAssignableVirtualWidget: AnyObject {
    var parent: VirtualWidget? { get set }
}

@MainActor
protocol VirtualContainerWidgetProtocol: AnyObject {
    var childGroupsValue: [String: [VirtualWidget]]? { get }
}
