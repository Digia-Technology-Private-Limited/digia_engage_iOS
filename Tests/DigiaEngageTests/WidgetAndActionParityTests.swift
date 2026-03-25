import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("Widget and Action Parity")
struct WidgetAndActionParityTests {
    @Test("action factory and processor route every action type one-by-one")
    func actionFactoryRoutesAllActionTypes() throws {
        for actionType in ActionType.allCases {
            let step = ActionStep(type: actionType.rawValue, data: nil, disableActionIf: nil)
            let action = try ActionFactory.makeAction(from: step)
            let routedType = ActionProcessorFactory.processorType(for: action)
            #expect(routedType == actionType)
        }
    }

    @Test("virtual widget registry builds every supported widget type one-by-one")
    func widgetRegistryBuildsAllSupportedTypes() throws {
        let registry = DefaultVirtualWidgetRegistry()
        let widgets: [(String, String, Any.Type)] = [
            ("fw/scaffold", "{}", VWScaffold.self),
            ("digia/container", "{}", VWContainer.self),
            ("digia/column", "{}", VWFlex.self),
            ("digia/row", "{}", VWFlex.self),
            ("digia/stack", "{}", VWStack.self),
            ("digia/text", #"{"text":"hello"}"#, VWText.self),
            ("digia/richText", #"{"textSpans":[{"text":"hello"}]}"#, VWRichText.self),
            ("digia/button", #"{"text":{"text":"tap"}}"#, VWButton.self),
            ("digia/streamBuilder", #"{"controller":"${appState.countStream}"}"#, VWStreamBuilder.self),
            ("digia/image", "{}", VWImage.self),
            ("digia/opacity", #"{"opacity":0.5}"#, VWOpacity.self),
            ("digia/lottie", "{}", VWLottie.self),
            ("fw/sized_box", "{}", VWSizedBox.self),
            ("digia/conditionalBuilder", "{}", VWConditionalBuilder.self),
            ("digia/conditionalItem", "{}", VWConditionItem.self),
            ("digia/linearProgressBar", "{}", VWLinearProgressBar.self),
            ("digia/circularProgressBar", "{}", VWCircularProgressBar.self),
            ("digia/horizontalDivider", "{}", VWStyledHorizontalDivider.self),
            ("digia/verticalDivider", "{}", VWStyledVerticalDivider.self),
            ("digia/styledHorizontalDivider", "{}", VWStyledHorizontalDivider.self),
            ("digia/styledVerticalDivider", "{}", VWStyledVerticalDivider.self),
            ("digia/carousel", "{}", VWCarousel.self),
            ("digia/wrap", "{}", VWWrap.self),
            ("digia/story", "{}", VWStory.self),
            ("digia/storyVideoPlayer", #"{"videoUrl":"https://example.com/story.mp4"}"#, VWStoryVideoPlayer.self),
            ("digia/scratchCard", #"{"width":"150","height":"150","brushSize":25}"#, VWScratchCard.self),
            ("digia/textFormField", "{}", VWTextFormField.self),
            ("digia/videoPlayer", #"{"videoUrl":"https://example.com/video.mp4"}"#, VWVideoPlayer.self),
            ("digia/timer", #"{"duration":10,"initialValue":10,"updateInterval":1,"timerType":"countDown"}"#, VWTimer.self),
        ]

        for (type, props, expectedType) in widgets {
            let data = try decodeWidgetData(type: type, propsJSON: props)
            let widget = try registry.createWidget(data, parent: nil)
            #expect(Swift.type(of: widget) == expectedType)
        }
    }

    @Test("unsupported widget types render unsupported placeholder")
    func unsupportedWidgetTypeRendersPlaceholder() throws {
        let registry = DefaultVirtualWidgetRegistry()
        let data = try decodeWidgetData(type: "digia/not-implemented", propsJSON: "{}")
        let widget = try registry.createWidget(data, parent: nil)
        #expect(widget is VWUnsupported)
    }

    private func decodeWidgetData(type: String, propsJSON: String) throws -> VWData {
        let json = """
        {
          "category": "widget",
          "type": "\(type)",
          "props": \(propsJSON),
          "children": []
        }
        """
        let payload = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(VWData.self, from: payload)
    }
}
