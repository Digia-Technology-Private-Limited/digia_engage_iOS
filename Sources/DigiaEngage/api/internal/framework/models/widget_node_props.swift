import Foundation

enum WidgetNodeProps: Equatable, Sendable {
    case scaffold(ScaffoldProps)
    case container(ContainerProps)
    case flex(FlexProps)
    case stack(StackProps)
    case text(TextProps)
    case richText(RichTextProps)
    case button(ButtonProps)
    case avatar(AvatarProps)
    case gridView(GridViewProps)
    case streamBuilder(StreamBuilderProps)
    case image(ImageProps)
    case opacity(OpacityProps)
    case lottie(LottieProps)
    case sizedBox(SizedBoxProps)
    case conditionalBuilder(ConditionalBuilderProps)
    case conditionalItem(ConditionalItemProps)
    case linearProgressBar(LinearProgressBarProps)
    case circularProgressBar(CircularProgressBarProps)
    case styledHorizontalDivider(StyledDividerProps)
    case styledVerticalDivider(StyledDividerProps)
    case carousel(CarouselProps)
    case wrap(WrapProps)
    case story(StoryProps)
    case storyVideoPlayer(StoryVideoPlayerProps)
    case scratchCard(ScratchCardProps)
    case textFormField(TextFormFieldProps)
    case videoPlayer(VideoPlayerProps)
    case timer(TimerProps)
    case unsupported

    static func decode(
        type: String,
        from container: KeyedDecodingContainer<VWNodeData.CodingKeys>,
        forKey key: VWNodeData.CodingKeys
    ) throws -> WidgetNodeProps {
        switch type {
        case "fw/scaffold", "digia/scaffold":
            return .scaffold(try container.decodeIfPresent(ScaffoldProps.self, forKey: key) ?? ScaffoldProps())
        case "digia/container":
            return .container(try container.decodeIfPresent(ContainerProps.self, forKey: key) ?? ContainerProps())
        case "digia/column", "digia/row":
            return .flex(try container.decodeIfPresent(FlexProps.self, forKey: key) ?? FlexProps())
        case "digia/stack":
            return .stack(try container.decodeIfPresent(StackProps.self, forKey: key) ?? StackProps())
        case "digia/text":
            // Work around deep nested decoder crashes by decoding text props through JSONValue.
            if let textScope = try container.decodeIfPresent(JSONValue.self, forKey: key) {
                return .text(TextProps(JSONValue: textScope))
            } else {
                return .text(TextProps(JSONValue: nil))
            }
        case "digia/richText":
            return .richText(try container.decode(RichTextProps.self, forKey: key))
        case "digia/button":
            return .button(try container.decode(ButtonProps.self, forKey: key))
        case "digia/avatar":
            return .avatar(try container.decode(AvatarProps.self, forKey: key))
        case "digia/gridView":
            return .gridView(try container.decode(GridViewProps.self, forKey: key))
        case "digia/streamBuilder":
            return .streamBuilder(try container.decode(StreamBuilderProps.self, forKey: key))
        case "digia/image":
            return .image(try container.decode(ImageProps.self, forKey: key))
        case "digia/opacity":
            return .opacity(try container.decode(OpacityProps.self, forKey: key))
        case "digia/lottie":
            return .lottie(try container.decode(LottieProps.self, forKey: key))
        case "fw/sized_box":
            return .sizedBox(try container.decodeIfPresent(SizedBoxProps.self, forKey: key) ?? SizedBoxProps())
        case "digia/conditionalBuilder":
            return .conditionalBuilder(try container.decodeIfPresent(ConditionalBuilderProps.self, forKey: key) ?? ConditionalBuilderProps())
        case "digia/conditionalItem":
            return .conditionalItem(try container.decode(ConditionalItemProps.self, forKey: key))
        case "digia/linearProgressBar":
            return .linearProgressBar(try container.decode(LinearProgressBarProps.self, forKey: key))
        case "digia/circularProgressBar":
            return .circularProgressBar(try container.decode(CircularProgressBarProps.self, forKey: key))
        case "digia/horizontalDivider", "digia/styledHorizontalDivider":
            return .styledHorizontalDivider(try container.decodeIfPresent(StyledDividerProps.self, forKey: key) ?? StyledDividerProps())
        case "digia/verticalDivider", "digia/styledVerticalDivider":
            return .styledVerticalDivider(try container.decodeIfPresent(StyledDividerProps.self, forKey: key) ?? StyledDividerProps())
        case "digia/carousel":
            return .carousel(try container.decode(CarouselProps.self, forKey: key))
        case "digia/wrap":
            return .wrap(try container.decode(WrapProps.self, forKey: key))
        case "digia/story":
            return .story(try container.decode(StoryProps.self, forKey: key))
        case "digia/storyVideoPlayer":
            return .storyVideoPlayer(try container.decode(StoryVideoPlayerProps.self, forKey: key))
        case "digia/scratchCard":
            return .scratchCard(try container.decode(ScratchCardProps.self, forKey: key))
        case "digia/textFormField":
            return .textFormField(try container.decode(TextFormFieldProps.self, forKey: key))
        case "digia/videoPlayer":
            return .videoPlayer(try container.decode(VideoPlayerProps.self, forKey: key))
        case "digia/timer":
            return .timer(try container.decode(TimerProps.self, forKey: key))
        default:
            return .unsupported
        }
    }
}
