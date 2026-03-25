import SwiftUI

@MainActor
final class VWSizedBox: VirtualLeafStatelessWidget<SizedBoxProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let width = payload.eval(props.width).map { CGFloat($0) }
        let height = payload.eval(props.height).map { CGFloat($0) }
        return AnyView(
            Rectangle()
                .fill(Color.clear)
                .frame(width: width ?? 0, height: height ?? 0)
        )
    }
}
