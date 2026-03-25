import Foundation
import AVFoundation
import CoreGraphics
@testable import DigiaEngage
import Testing

@Suite("Widget Runtime Parity")
struct WidgetRuntimeParityTests {
    @Test("common style decodes intrinsic and percentage sizing metadata")
    func commonStyleDecodesRawSizingMetadata() throws {
        let props: CommonProps = try decode("""
        {
          "style": {
            "width": "100%",
            "height": "intrinsic",
            "border": {
              "borderWidth": 2,
              "borderColor": "#111111",
              "strokeAlign": "center",
              "borderType": {
                "borderPattern": "dashed",
                "dashPattern": [4, 2],
                "strokeCap": "round"
              }
            }
          }
        }
        """)

        #expect(props.style?.widthRaw == "100%")
        #expect(props.style?.heightRaw == "intrinsic")
        #expect(props.style?.border?.borderColor == .value("#111111"))
        #expect(props.style?.border?.borderType?.borderPattern == "dashed")
        #expect(props.style?.border?.borderType?.dashPattern == [4, 2])
    }

    @Test("container border styling resolves dotted borders like Flutter")
    func containerBorderStylingMatchesFlutterDottedBehavior() throws {
        let dotted: BorderStyle = try decode("""
        {
          "borderWidth": 2,
          "borderColor": "#111111",
          "strokeAlign": "center",
          "borderType": {
            "borderPattern": "dotted",
            "dashPattern": [20, 20],
            "strokeCap": "butt"
          }
        }
        """)

        let dottedConfiguration = DigiaBorderStrokeConfiguration.resolve(border: dotted)
        #expect(dottedConfiguration.lineCap == .round)
        #expect(dottedConfiguration.dashPattern.count == 2)
        #expect(abs(dottedConfiguration.dashPattern[0] - 2) < 0.0001)
        #expect(abs(dottedConfiguration.dashPattern[1] - 4) < 0.0001)

        let dashed: BorderStyle = try decode("""
        {
          "borderWidth": 2,
          "borderColor": "#111111",
          "borderType": {
            "borderPattern": "dashed",
            "dashPattern": [4, 2],
            "strokeCap": "square"
          }
        }
        """)

        let dashedConfiguration = DigiaBorderStrokeConfiguration.resolve(border: dashed)
        #expect(dashedConfiguration.lineCap == .square)
        #expect(dashedConfiguration.dashPattern == [4, 2])
    }

    @Test("parent props decode expansion type and evaluatable positioned values")
    func parentPropsDecodeExpansionAndPosition() throws {
        let props: ParentProps = try decode("""
        {
          "expansion": {
            "type": "tight",
            "flexValue": "${state.flex}"
          },
          "position": {
            "left": "${state.left}",
            "top": 16,
            "width": 120
          }
        }
        """)

        #expect(props.expansion?.type == "tight")
        #expect(props.expansion?.flexValue == .expression("${state.flex}"))
        #expect(props.position?.left == .expression("${state.left}"))
        #expect(props.position?.top == .value(16))
        #expect(props.position?.width == .value(120))
    }

    @Test("rich text props coerce string and object spans into span array")
    func richTextPropsCoerceSpanInputs() throws {
        let props: RichTextProps = try decode("""
        {
          "textSpans": [
            "Hello",
            {
              "text": " world",
              "onClick": {
                "steps": []
              }
            }
          ]
        }
        """)

        #expect(props.textSpans.count == 2)
        #expect(props.textSpans.first?.text == .value("Hello"))
        #expect(props.textSpans.last?.text == .value(" world"))
        #expect(props.textSpans.last?.onClick?.steps.isEmpty == true)
    }

    @Test("carousel props decode data source and nested indicator settings")
    func carouselPropsDecodeDataSourceAndIndicatorSettings() throws {
        let props: CarouselProps = try decode("""
        {
          "width": "320",
          "dataSource": "${state.items}",
          "indicator": {
            "indicatorAvailable": {
              "showIndicator": true,
              "dotHeight": 10,
              "dotWidth": 12,
              "spacing": 6,
              "dotColor": "#999999",
              "activeDotColor": "#111111",
              "indicatorEffectType": "worm"
            }
          }
        }
        """)

        #expect(props.width == .expression("320"))
        #expect(props.dataSource == .string("${state.items}"))
        #expect(props.showIndicator == true)
        #expect(props.dotHeight == 10)
        #expect(props.dotWidth == 12)
        #expect(props.spacing == 6)
        #expect(props.indicatorEffectType == "worm")
    }

    @Test("divider props decode styled and legacy variants")
    func dividerPropsDecodeStyledAndLegacyVariants() throws {
        let styled: StyledDividerProps = try decode("""
        {
          "thickness": 2,
          "indent": 12,
          "endIndent": 8,
          "height": 18,
          "colorType": {
            "color": "#123456",
            "gradiant": {
              "type": "linear",
              "begin": "topLeft",
              "end": "bottomRight",
              "center": "center",
              "radius": 0.75,
              "colorList": [
                { "color": "#111111", "stop": 0.0 },
                { "color": "#ffffff", "stop": 1.0 }
              ]
            }
          },
          "borderPattern": {
            "value": "dashed",
            "strokeCap": "round",
            "dashPattern": [4, 2]
          }
        }
        """)

        #expect(styled.thickness == .value(2))
        #expect(styled.indent == .value(12))
        #expect(styled.endIndent == .value(8))
        #expect(styled.size.height == .value(18))
        #expect(styled.color == .value("#123456"))
        #expect(styled.gradient?.type == "linear")
        #expect(styled.gradient?.colorList?.count == 2)
        #expect(styled.borderPattern == "dashed")
        #expect(styled.strokeCap == "round")
        #expect(styled.dashPattern == [4, 2])

        let legacy: StyledDividerProps = try decode("""
        {
          "thickness": 3,
          "lineStyle": "dotted",
          "width": 20,
          "indent": 4,
          "endIndent": 6,
          "color": "#abcdef"
        }
        """)

        #expect(legacy.thickness == .value(3))
        #expect(legacy.lineStyle == "dotted")
        #expect(legacy.size.width == .value(20))
        #expect(legacy.indent == .value(4))
        #expect(legacy.endIndent == .value(6))
        #expect(legacy.color == .value("#abcdef"))
    }

    @Test("wrap props decode layout and data source settings")
    func wrapPropsDecodeLayoutAndDataSourceSettings() throws {
        let props: WrapProps = try decode("""
        {
          "dataSource": "${state.items}",
          "spacing": 10,
          "runSpacing": 14,
          "wrapAlignment": "spaceBetween",
          "wrapCrossAlignment": "center",
          "runAlignment": "end",
          "direction": "vertical",
          "verticalDirection": "up",
          "clipBehavior": "hardEdge"
        }
        """)

        #expect(props.dataSource == .string("${state.items}"))
        #expect(props.spacing == .value(10))
        #expect(props.runSpacing == .value(14))
        #expect(props.wrapAlignment == .value("spaceBetween"))
        #expect(props.wrapCrossAlignment == .value("center"))
        #expect(props.runAlignment == .value("end"))
        #expect(props.direction == .value("vertical"))
        #expect(props.verticalDirection == .value("up"))
        #expect(props.clipBehavior == .value("hardEdge"))
    }

    @Test("text form field props decode validation formatting and borders")
    func textFormFieldPropsDecodeValidationFormattingAndBorders() throws {
        let props: TextFormFieldProps = try decode("""
        {
          "initialValue": "hello",
          "maxLines": 4,
          "minLines": 2,
          "maxLength": 12,
          "debounceValue": 250,
          "labelText": "Name",
          "hintText": "Enter name",
          "validationRules": [
            { "type": "required", "errorMessage": "Required" },
            { "type": "minLength", "errorMessage": "Too short", "data": 3 },
            { "type": "pattern", "errorMessage": "Invalid", "data": "^[a-z]+$" }
          ],
          "inputFormatters": [
            { "type": "allow", "regex": "[a-z]" }
          ],
          "enabledBorder": {
            "borderWidth": 2,
            "borderColor": "#111111",
            "borderType": {
              "value": "outlineDashedInputBorder",
              "dashPattern": [4, 2]
            }
          }
        }
        """)

        #expect(props.initialValue == .value("hello"))
        #expect(props.maxLines == .value(4))
        #expect(props.minLines == .value(2))
        #expect(props.maxLength == .value(12))
        #expect(props.debounceValue == .value(250))
        #expect(props.labelText == .value("Name"))
        #expect(props.hintText == .value("Enter name"))
        #expect(props.validationRules?.count == 3)
        #expect(props.inputFormatters?.count == 1)
        #expect(props.enabledBorder?.borderWidth == .value(2))
        #expect(props.enabledBorder?.borderColor == .value("#111111"))
        #expect(props.enabledBorder?.borderType?.value == "outlineDashedInputBorder")
        #expect(props.enabledBorder?.borderType?.dashPattern == [4, 2])
    }

    @Test("video player props decode playback defaults")
    func videoPlayerPropsDecodePlaybackDefaults() throws {
        let props: VideoPlayerProps = try decode("""
        {
          "videoUrl": "https://example.com/video.mp4",
          "showControls": false,
          "aspectRatio": 1.77,
          "autoPlay": false,
          "looping": true
        }
        """)

        #expect(props.videoURL == .string("https://example.com/video.mp4"))
        #expect(props.showControls == .value(false))
        #expect(props.aspectRatio == .value(1.77))
        #expect(props.autoPlay == .value(false))
        #expect(props.looping == .value(true))
    }

    @Test("timer props decode countdown configuration")
    func timerPropsDecodeCountdownConfiguration() throws {
        let props: TimerProps = try decode("""
        {
          "duration": 10,
          "initialValue": 12,
          "updateInterval": 2,
          "timerType": "countDown",
          "onTick": {
            "steps": []
          },
          "onTimerEnd": {
            "steps": []
          }
        }
        """)

        #expect(props.duration == .value(10))
        #expect(props.initialValue == .value(12))
        #expect(props.updateInterval == .value(2))
        #expect(props.isCountDown == true)
        #expect(props.onTick?.steps.isEmpty == true)
        #expect(props.onTimerEnd?.steps.isEmpty == true)
    }

    @Test("scratch card props decode interaction and animation settings")
    func scratchCardPropsDecodeInteractionAndAnimationSettings() throws {
        let props: ScratchCardProps = try decode("""
        {
          "width": "150",
          "height": "120",
          "brushSize": 25,
          "revealFullAtPercent": 50,
          "isScratchingEnabled": true,
          "gridResolution": 10,
          "enableTapToScratch": false,
          "brushColor": "#000000",
          "brushOpacity": 1,
          "brushShape": "circle",
          "enableHapticFeedback": false,
          "revealAnimationType": "fade",
          "animationDurationMs": 300,
          "enableProgressAnimation": false,
          "onScratchComplete": {
            "steps": []
          }
        }
        """)

        #expect(props.width == "150")
        #expect(props.height == "120")
        #expect(props.brushSize == .value(25))
        #expect(props.revealFullAtPercent == .value(50))
        #expect(props.isScratchingEnabled == .value(true))
        #expect(props.gridResolution == .value(10))
        #expect(props.enableTapToScratch == .value(false))
        #expect(props.brushColor == .value("#000000"))
        #expect(props.brushOpacity == .value(1))
        #expect(props.brushShape == .value("circle"))
        #expect(props.enableHapticFeedback == .value(false))
        #expect(props.revealAnimationType == .value("fade"))
        #expect(props.animationDurationMs == .value(300))
        #expect(props.enableProgressAnimation == .value(false))
        #expect(props.onScratchComplete?.steps.isEmpty == true)
    }

    @Test("timer controller publishes countdown ticks and completion")
    func timerControllerPublishesCountdownTicks() async throws {
        let controller = DigiaTimerController(
            initialValue: 2,
            updateInterval: 0.01,
            isCountDown: true,
            duration: 2
        )
        let recorder = TimerRecorder()
        let tickToken = controller.subscribe { value in
            guard let value = value as? Int else { return }
            Task {
                await recorder.recordTick(value)
            }
        }
        let completionToken = controller.subscribeCompletion { value in
            Task {
                await recorder.recordCompletion(value)
            }
        }

        controller.start()
        try await Task.sleep(for: .milliseconds(80))

        controller.unsubscribe(tickToken)
        controller.unsubscribeCompletion(completionToken)
        controller.dispose()

        let ticks = await recorder.ticks
        let completionValue = await recorder.completionValue

        #expect(ticks == [2, 1, 0])
        #expect(completionValue == 0)
    }

    @MainActor
    @Test("story props decode indicator and playback settings")
    func storyPropsDecodeIndicatorAndPlaybackSettings() throws {
        let props: StoryProps = try decode("""
        {
          "dataSource": "${state.items}",
          "initialIndex": 2,
          "restartOnCompleted": true,
          "duration": 4500,
          "indicator": {
            "activeColor": "#ffffff",
            "backgroundCompletedColor": "#eeeeee",
            "backgroundDisabledColor": "#111111",
            "height": 6,
            "borderRadius": 8,
            "horizontalGap": 10
          }
        }
        """)

        #expect(props.dataSource == .string("${state.items}"))
        #expect(props.initialIndex == .value(2))
        #expect(props.restartOnCompleted == .value(true))
        #expect(props.duration == .value(4500))
        #expect(props.indicator?.height == 6)
        #expect(props.indicator?.borderRadius == 8)
        #expect(props.indicator?.horizontalGap == 10)
    }

    @MainActor
    @Test("story playback coordinator advances and repeats")
    func storyPlaybackCoordinatorAdvancesAndRepeats() async throws {
        let coordinator = StoryPlaybackCoordinator(
            pageCount: 2,
            initialIndex: 5,
            repeatOnCompleted: true,
            defaultDuration: 1.0,
            onCompleted: nil,
            onPreviousCompleted: nil,
            onStoryChanged: nil
        )

        #expect(coordinator.currentIndex == 1)

        coordinator.moveToPrevious()
        #expect(coordinator.currentIndex == 0)

        coordinator.confirmNoVideoDetected(for: coordinator.generation)
        try await Task.sleep(for: .milliseconds(20))
        coordinator.tick(delta: 1.0)
        #expect(coordinator.currentIndex == 1)

        coordinator.confirmNoVideoDetected(for: coordinator.generation)
        try await Task.sleep(for: .milliseconds(20))
        coordinator.tick(delta: 1.0)
        #expect(coordinator.currentIndex == 0)
    }

    @MainActor
    @Test("story playback coordinator waits for video and follows player progress")
    func storyPlaybackCoordinatorTracksVideoProgress() {
        let coordinator = StoryPlaybackCoordinator(
            pageCount: 1,
            initialIndex: 0,
            repeatOnCompleted: false,
            defaultDuration: 3.0,
            onCompleted: nil,
            onPreviousCompleted: nil,
            onStoryChanged: nil
        )
        let player = AVPlayer()

        coordinator.registerVideoLoading(for: coordinator.generation)
        #expect(coordinator.mode == StoryPlaybackCoordinator.Mode.detectingVideo)

        coordinator.registerVideo(player: player, duration: 5.0, autoPlay: false, generation: coordinator.generation)
        #expect(coordinator.mode == .video)
        #expect(abs(coordinator.progress - 0) < 0.0001)
    }

    @Test("story video playback bundle uses queue player only when looping")
    func storyVideoPlaybackBundleCreatesExpectedPlayerTypes() throws {
        let url = try #require(URL(string: "https://example.com/story.mp4"))

        let nonLooping = StoryVideoPlaybackBundle.make(url: url, looping: false)
        #expect(type(of: nonLooping.player) == AVPlayer.self)
        #expect(nonLooping.looper == nil)

        let looping = StoryVideoPlaybackBundle.make(url: url, looping: true)
        #expect(looping.player is AVQueuePlayer)
        #expect(looping.looper != nil)
    }

    @Test("video playback bundle uses queue player only when looping")
    func videoPlaybackBundleCreatesExpectedPlayerTypes() throws {
        let url = try #require(URL(string: "https://example.com/video.mp4"))

        let nonLooping = DigiaVideoPlaybackBundle.make(url: url, looping: false)
        #expect(type(of: nonLooping.player) == AVPlayer.self)
        #expect(nonLooping.looper == nil)

        let looping = DigiaVideoPlaybackBundle.make(url: url, looping: true)
        #expect(looping.player is AVQueuePlayer)
        #expect(looping.looper != nil)
    }

    @MainActor
    @Test("video player model rejects unsupported url schemes")
    func videoPlayerModelRejectsUnsupportedSchemes() async {
        let model = DigiaVideoPlayerModel()
        await model.load(urlString: "ftp://example.com/video.mp4", preferredAspectRatio: nil, looping: false)

        #expect(model.player == nil)
        #expect(model.errorMessage == "Unsupported video URL")
        #expect(abs(model.aspectRatio - (16.0 / 9.0)) < 0.0001)
    }
}

private actor TimerRecorder {
    private(set) var ticks: [Int] = []
    private(set) var completionValue: Int?

    func recordTick(_ value: Int) {
        ticks.append(value)
    }

    func recordCompletion(_ value: Int) {
        completionValue = value
    }
}

private func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}
