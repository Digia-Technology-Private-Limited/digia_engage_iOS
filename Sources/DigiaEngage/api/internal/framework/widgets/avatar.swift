import SwiftUI

@MainActor
final class VWAvatar: VirtualLeafStatelessWidget<AvatarProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        AnyView(DigiaAvatarView(widget: self, payload: payload))
    }
}

private struct DigiaAvatarView: View {
    let widget: VWAvatar
    let payload: RenderPayload

    private var props: AvatarProps { widget.props }

    var body: some View {
        switch resolvedShape {
        case .square(let side, let cornerRadius):
            avatarContent
                .frame(width: side, height: side)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .circle(let size):
            avatarContent
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }

    private var backgroundColor: Color {
        payload.evalColor(props.bgColor) ?? .gray
    }

    private var avatarContent: some View {
        Group {
            if let imageProps = props.image,
               let imageSource = payload.eval(imageProps.imageSrc) ?? payload.eval(imageProps.src?.imageSrc),
               !imageSource.isEmpty {
                VWImage(
                    props: imageProps,
                    commonProps: nil,
                    parentProps: nil,
                    parent: widget,
                    refName: nil
                )
                .toWidget(payload)
            } else if let textProps = props.text {
                VWText(
                    props: textProps,
                    commonProps: nil,
                    parentProps: nil,
                    parent: widget,
                    refName: nil
                )
                .toWidget(payload)
            } else {
                Color.clear
            }
        }
    }

    private var resolvedShape: DigiaAvatarShape {
        switch props.shape?.value?.lowercased() {
        case "square":
            let side = CGFloat(props.shape?.side ?? 32)
            let cornerRadius = CGFloat(props.shape?.cornerRadius?.edgeInsets.top ?? 0)
            return .square(side: side, cornerRadius: cornerRadius)
        default:
            let radius = CGFloat(props.shape?.radius ?? 16)
            return .circle(size: max(radius * 2, 0))
        }
    }
}

private enum DigiaAvatarShape {
    case circle(size: CGFloat)
    case square(side: CGFloat, cornerRadius: CGFloat)
}
