import SwiftUI

@MainActor
final class VWStyledVerticalDivider: VirtualLeafStatelessWidget<StyledDividerProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let thickness = CGFloat(payload.eval(props.thickness) ?? 1)
        let configuration = DividerStrokeConfiguration.resolve(props: props, thickness: thickness)

        return AnyView(
            DigiaDividerView(
                axis: .vertical,
                size: CGFloat(payload.eval(props.size.width) ?? 16),
                thickness: thickness,
                indent: CGFloat(payload.eval(props.indent) ?? 0),
                endIndent: CGFloat(payload.eval(props.endIndent) ?? 0),
                color: payload.evalColor(props.color) ?? .black,
                gradient: props.gradient,
                strokeCap: configuration.strokeCap,
                dashPattern: configuration.dashPattern,
                minLength: max(thickness, 1),
                maxLength: nil,
                showsFallbackLength: false,
                payload: payload
            )
        )
    }
}
