import SwiftUI

// MARK: - Child group decoding

/// Decodes a map of raw JSONValue arrays into a map of resolved VirtualWidget arrays,
/// one level at a time to avoid recursive JSONDecoder stack frames.
@MainActor
func createChildGroups(
    _ childGroups: [String: [JSONValue]],
    _ parent: VirtualWidget?,
    _ registry: VirtualWidgetRegistry
) throws -> [String: [VirtualWidget]]? {
    guard !childGroups.isEmpty else { return nil }
    let decoder = JSONDecoder()
    return try childGroups.mapValues { group in
        try group.map { jsonValue in
            let data = try JSONEncoder().encode(jsonValue)
            let vwData = try decoder.decode(VWData.self, from: data)
            return try registry.createWidget(vwData, parent: parent)
        }
    }
}

// MARK: - Default widget registry

/// Maps VWData nodes to VirtualWidget instances.
/// This is the Swift equivalent of Flutter's builders.dart — the central
/// place that knows how to construct every widget type from its data model.
@MainActor
final class DefaultVirtualWidgetRegistry: VirtualWidgetRegistry {
    func createWidget(_ data: VWData, parent: VirtualWidget?) throws -> VirtualWidget {
        switch data {
        case let .widget(node):
            return try buildWidget(node: node, parent: parent)
        case let .component(component):
            return VWComponent(
                componentId: component.id,
                args: component.args ?? [:],
                commonProps: component.commonProps,
                parentProps: component.parentProps,
                parent: parent,
                refName: component.refName,
                registry: self
            )
        }
    }

    // MARK: - Widget builders

    private func buildWidget(node: VWNodeData, parent: VirtualWidget?) throws -> VirtualWidget {
        switch node.props {
        case let .scaffold(props):
            return try withChildren(VWScaffold(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .container(props):
            return try withChildren(VWContainer(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .flex(props):
            let direction: VWFlex.Direction = node.type == "digia/row" ? .horizontal : .vertical
            return try withChildren(VWFlex(direction: direction, props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .stack(props):
            return try withChildren(VWStack(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .text(props):
            return VWText(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .richText(props):
            return VWRichText(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .button(props):
            return VWButton(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .avatar(props):
            return VWAvatar(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .gridView(props):
            return try withChildren(VWGridView(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .streamBuilder(props):
            return try withChildren(VWStreamBuilder(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .image(props):
            return VWImage(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .opacity(props):
            return try withChildren(VWOpacity(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .lottie(props):
            return VWLottie(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .sizedBox(props):
            return VWSizedBox(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case .conditionalBuilder:
            let widget = VWConditionalBuilder(parentProps: node.parentProps, childGroups: nil)
            try attachChildGroups(node.childGroups, to: widget)
            return widget
        case let .conditionalItem(props):
            return try withChildren(VWConditionItem(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .linearProgressBar(props):
            return VWLinearProgressBar(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .circularProgressBar(props):
            return VWCircularProgressBar(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .styledHorizontalDivider(props):
            return VWStyledHorizontalDivider(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .styledVerticalDivider(props):
            return VWStyledVerticalDivider(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .carousel(props):
            return try withChildren(VWCarousel(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .wrap(props):
            return try withChildren(VWWrap(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .story(props):
            return try withChildren(VWStory(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .storyVideoPlayer(props):
            return VWStoryVideoPlayer(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .scratchCard(props):
            return try withChildren(VWScratchCard(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .textFormField(props):
            return try withChildren(VWTextFormField(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case let .videoPlayer(props):
            return VWVideoPlayer(props: props, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        case let .timer(props):
            return try withChildren(VWTimer(props: props, commonProps: node.commonProps, parentProps: node.parentProps, childGroups: nil, parent: parent, refName: node.refName), node: node)
        case .unsupported:
            let detail: String?
            if node.type == "digia/unsupported", case let .string(reason)? = node.repeatData {
                detail = reason
            } else {
                detail = nil
            }
            return VWUnsupported(type: node.type, detail: detail, commonProps: node.commonProps, parentProps: node.parentProps, parent: parent, refName: node.refName)
        }
    }

    // MARK: - Helpers

    private func withChildren<W: VirtualWidget>(_ widget: W, node: VWNodeData) throws -> W {
        try attachChildGroups(node.childGroups, to: widget)
        return widget
    }

    private func attachChildGroups(_ nodeGroups: [String: [JSONValue]], to widget: VirtualWidget) throws {
        guard !nodeGroups.isEmpty else { return }
        let groups = try createChildGroups(nodeGroups, widget, self)
        (widget as? ChildGroupsAssignable)?.childGroups = groups
    }
}
