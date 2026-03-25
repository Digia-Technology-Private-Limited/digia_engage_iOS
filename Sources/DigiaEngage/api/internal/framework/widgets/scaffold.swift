import SwiftUI

@MainActor
final class VWScaffold: VirtualStatelessWidget<ScaffoldProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        let bodyWidget = childOf("body") ?? children?.first
        let background = payload.evalColor(props.scaffoldBackgroundColor) ?? .clear
        let enableSafeArea = payload.eval(props.enableSafeArea) ?? true
        let bodyContent = bodyWidget?.toWidget(payload) ?? empty()
        let content = AnyView(bodyContent.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))

        if enableSafeArea {
            return AnyView(
                ZStack(alignment: .topLeading) {
                    background.ignoresSafeArea()
                    content
                }
            )
        }

        return AnyView(
            ZStack(alignment: .topLeading) {
                background.ignoresSafeArea()
                content.ignoresSafeArea()
            }
        )
    }
}
