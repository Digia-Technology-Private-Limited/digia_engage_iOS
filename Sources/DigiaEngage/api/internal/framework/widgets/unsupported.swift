import SwiftUI

@MainActor
final class VWUnsupported: VirtualLeafStatelessWidget<Void> {
    let type: String
    private let detail: String?

    init(
        type: String,
        detail: String? = nil,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        parent: VirtualWidget?,
        refName: String?
    ) {
        self.type = type
        self.detail = detail
        super.init(
            props: (),
            commonProps: commonProps,
            parentProps: parentProps,
            parent: parent,
            refName: refName
        )
    }

    override func render(_ payload: RenderPayload) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Text("Unsupported widget")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Text(type)
                    .font(.caption.monospaced())
                if let detail {
                    Text(detail)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            }
        )
    }
}
