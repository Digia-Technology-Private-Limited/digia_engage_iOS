import SwiftUI

@MainActor
final class VWLinearProgressBar: VirtualLeafStatelessWidget<LinearProgressBarProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let progress = NumUtil.normalizeProgress(payload.eval(props.progressValue) ?? 0)
        let width = payload.eval(props.width).map { CGFloat($0) }
        let thickness = CGFloat(payload.eval(props.thickness) ?? 5)
        let radius = CGFloat(payload.eval(props.borderRadius) ?? 0)
        let tint = payload.evalColor(props.indicatorColor) ?? .blue
        let background = payload.evalColor(props.bgColor) ?? .clear
        let reversed = payload.eval(props.isReverse) ?? false

        if props.type == "determinate" {
            return AnyView(
                DigiaDeterminateLinearBar(
                    progress: progress,
                    width: width,
                    thickness: thickness,
                    radius: radius,
                    tint: tint,
                    background: background,
                    reversed: reversed,
                    animate: props.animation ?? false
                )
            )
        }

        return AnyView(
            DigiaIndeterminateLinearBar(
                width: width,
                thickness: thickness,
                radius: radius,
                tint: tint,
                background: background,
                reversed: reversed
            )
        )
    }
}
